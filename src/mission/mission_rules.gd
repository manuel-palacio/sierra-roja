class_name MissionRules
extends Node
## Win and loss for the bridge mission. Win: the bridge is destroyed and both specialists are
## alive inside Mission.extraction(). Loss: either specialist dies, or the bridge goes down with
## one of them still unable to reach the extraction. The result is evaluated once per physics
## frame, loss first, and is final once it leaves RUNNING.
##
## Charges are created at runtime, so rules hook them through SceneTree.node_added (plus any
## already in the "charges" group). Neither the planting code nor save/load has to know about
## the rules; a charge restored by load_state hooks in as it enters the tree.

signal result_changed(result: Result)
signal bridge_blown()
## A charge went off while the bridge stood, too far away to destroy it.
signal charge_too_far()

enum Result { RUNNING, WON, LOST }

## A charge destroys the bridge when it goes off this close to Mission.bridge_target().
const BRIDGE_BLAST_RANGE := 8.0
const DEATH_TEXT := "A specialist was killed"
const CUT_OFF_TEXT := "The bridge is down and the squad is cut off from the extraction point"
## A path that ends this close to the extraction (on the ground plane) reaches it.
const REACH_TOLERANCE := 3.0

var result := Result.RUNNING
var bridge_destroyed := false

var _mission: Mission
var _specialists: Array[Specialist] = []
var _in_extraction: Dictionary = {}  # Specialist -> true
## The bridge is down and a living specialist has no way to the extraction.
var _cut_off := false


## Guards currently in ALARM; dead guards do not count.
var alarm_level: int:
	get:
		var n := 0
		for g in _mission.guards() if _mission else []:
			if g.alive and g.brain.state == GuardBrain.State.ALARM:
				n += 1
		return n


func setup(mission: Mission, specialists: Array[Specialist]) -> void:
	_mission = mission
	_specialists = specialists
	mission.rules = self
	mission.nav_rebaked.connect(_on_nav_rebaked)
	for s in specialists:
		s.died.connect(_on_specialist_died)
	var area := mission.extraction()
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		for body in area.get_overlapping_bodies():
			_on_body_entered(body)
	for charge in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		_hook(charge)
	get_tree().node_added.connect(_on_node_added)


func at_extraction(s: Specialist) -> bool:
	return s.alive and _in_extraction.has(s)


func _physics_process(_delta: float) -> void:
	evaluate()


## Runs one evaluation. Tests may call it directly.
func evaluate() -> void:
	if result != Result.RUNNING:
		return
	for s in _specialists:
		if not s.alive:
			_set_result(Result.LOST)
			return
	if _cut_off:
		_set_result(Result.LOST)
		return
	if not bridge_destroyed or _specialists.is_empty():
		return
	for s in _specialists:
		if not at_extraction(s):
			return
	_set_result(Result.WON)


## Why the mission was lost, for the player; "" unless it has been.
func loss_reason() -> String:
	if result != Result.LOST:
		return ""
	for s in _specialists:
		if not s.alive:
			return DEATH_TEXT
	return CUT_OFF_TEXT


func save_state() -> Dictionary:
	var inside: Array[String] = []
	for s in _in_extraction:
		inside.append(String((s as Specialist).name))
	return { "result": int(result), "bridge_destroyed": bridge_destroyed, "at_extraction": inside }


## Puts the bridge in the saved condition, broken or whole, with the navmesh to match. Who is at
## extraction comes from the save: the area only reports a teleport on the next physics step,
## and until then a stale answer could hand out a false win.
func load_state(d: Dictionary) -> void:
	bridge_destroyed = bool(d["bridge_destroyed"])
	if _mission:
		if bridge_destroyed:
			_mission.break_bridge()
		else:
			_mission.repair_bridge()
	_cut_off = false
	_in_extraction.clear()
	for s in _specialists:
		if d["at_extraction"].has(String(s.name)):
			_in_extraction[s] = true
	var loaded := int(d["result"]) as Result
	if loaded != result:
		result = loaded
		result_changed.emit(result)


## The navmesh changes when the bridge breaks. From then on, anyone who cannot walk to the
## extraction never will.
func _on_nav_rebaked() -> void:
	if not bridge_destroyed or result != Result.RUNNING or _mission.extraction() == null:
		return
	var goal := _mission.extraction().global_position
	var map := _mission.nav_map()
	for s in _specialists:
		if not s.alive or at_extraction(s):
			continue
		var path := NavigationServer3D.map_get_path(map, s.global_position, goal, true)
		if path.is_empty() or Vector2(path[-1].x - goal.x, path[-1].z - goal.z).length() > REACH_TOLERANCE:
			_cut_off = true
			return


func _set_result(r: Result) -> void:
	result = r
	result_changed.emit(r)


func _on_specialist_died(_unit: Unit) -> void:
	# Left to the next evaluation so a same-frame detonation cannot sneak a win in first.
	pass


func _on_body_entered(body: Node3D) -> void:
	if body is Specialist:
		_in_extraction[body] = true


func _on_body_exited(body: Node3D) -> void:
	_in_extraction.erase(body)


func _on_node_added(node: Node) -> void:
	if node is PlantedCharge:
		_hook(node)


func _hook(charge: PlantedCharge) -> void:
	if not charge.detonated.is_connected(_on_detonated):
		charge.detonated.connect(_on_detonated)


func _on_detonated(pos: Vector3) -> void:
	var target := _mission.bridge_target() if _mission else null
	if bridge_destroyed or target == null:
		return
	if pos.distance_to(target.global_position) > BRIDGE_BLAST_RANGE:
		charge_too_far.emit()
		return
	bridge_destroyed = true
	_drop_whoever_is_on_the_span()
	_mission.break_bridge()
	bridge_blown.emit()


## The span goes into the gorge and takes with it anyone the blast itself did not reach, and any
## body lying on it.
func _drop_whoever_is_on_the_span() -> void:
	var units: Array = []
	units.append_array(get_tree().get_nodes_in_group(Guard.GROUP))
	units.append_array(get_tree().get_nodes_in_group(Specialist.GROUP))
	for node in units:
		var unit := node as Unit
		if unit != null and unit.alive and _mission.is_ancestor_of(unit) and _mission.on_span(unit.global_position):
			unit.take_damage(unit.hp)
	for node in get_tree().get_nodes_in_group(Body.GROUP):
		var body := node as Body
		if body.carried_by == null and _mission.is_ancestor_of(body) and _mission.on_span(body.global_position):
			body.queue_free()
