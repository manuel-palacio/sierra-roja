class_name MissionRules
extends Node
## Win and loss for a mission. Win: every objective the mission lists is met and both specialists
## are alive inside Mission.extraction(). Loss: either specialist dies, an objective can no longer
## be met, or the pair is cut off from the extraction. The result is evaluated once per physics
## frame, loss first, and is final once it leaves RUNNING.
##
## Charges are created at runtime, so rules hook them through SceneTree.node_added (plus any
## already in the "charges" group) and hand each blast to the objectives that are about blasts.
## Neither the planting code nor save/load has to know about the rules; a charge restored by
## load_state hooks in as it enters the tree.

signal result_changed(result: Result)
## An objective has just been met.
signal objective_done(objective: Objective)
## A charge went off while something was still to be destroyed, too far from all of it.
signal charge_too_far()

enum Result { RUNNING, WON, LOST }

const DEATH_TEXT := "A specialist was killed"
const CUT_OFF_TEXT := "The squad is cut off from the extraction point"
## The same, on a mission with a bridge to be cut off by.
const BRIDGE_CUT_OFF_TEXT := "The bridge is down and the squad is cut off from the extraction point"
## Said when an objective fails and has no words of its own for it.
const OBJECTIVE_FAILED_FALLBACK := "The objective can no longer be met"
## A path that ends this close to the extraction (on the ground plane) reaches it.
const REACH_TOLERANCE := 3.0

var result := Result.RUNNING

var _mission: Mission
var _specialists: Array[Specialist] = []
var _in_extraction: Dictionary = {}  # Unit -> true
## The land has changed and a living specialist has no way to the extraction.
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
	for o in mission.objectives():
		_adopt(o)
	var area := mission.extraction()
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		for body in area.get_overlapping_bodies():
			_on_body_entered(body)
	for charge in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		_hook(charge)
	get_tree().node_added.connect(_on_node_added)


## The mission these rules judge.
func mission() -> Mission:
	return _mission


## The mission's objectives, in the order the player is told of them.
func objectives() -> Array[Objective]:
	return _mission.objectives() if _mission else ([] as Array[Objective])


func objectives_done() -> bool:
	return current_objective() == null


## The one to go for now: the first not yet met. Null when all are.
func current_objective() -> Objective:
	for o in objectives():
		if not o.done:
			return o
	return null


func is_at_extraction(unit: Unit) -> bool:
	return unit.alive and _in_extraction.has(unit)


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
	for o in objectives():
		o.update()
		if o.failed:
			_set_result(Result.LOST)
			return
	if _cut_off:
		_set_result(Result.LOST)
		return
	if not objectives_done() or _specialists.is_empty():
		return
	for s in _specialists:
		if not is_at_extraction(s):
			return
	_set_result(Result.WON)


## Why the mission was lost, for the player; "" unless it has been.
func loss_reason() -> String:
	if result != Result.LOST:
		return ""
	for s in _specialists:
		if not s.alive:
			return DEATH_TEXT
	for o in objectives():
		if o.failed:
			return o.fail_reason() if o.fail_reason() != "" else OBJECTIVE_FAILED_FALLBACK
	var has_bridge := _mission != null and (_mission.get_node_or_null("Nav/BridgeDeck") != null
			or _mission.get_node_or_null("Nav/BridgeBroken") != null)
	return BRIDGE_CUT_OFF_TEXT if has_bridge else CUT_OFF_TEXT


func save_state() -> Dictionary:
	var inside: Array[String] = []
	for unit in _in_extraction:
		inside.append(String((unit as Unit).name))
	var states: Array[Dictionary] = []
	for o in objectives():
		states.append(o.save_state())
	return { "result": int(result), "objectives": states, "at_extraction": inside }


## Puts every objective in its saved condition, and what it changed on the map with it: a bridge
## broken or whole, with the navmesh to match. Who is at extraction comes from the save: the area
## only reports a teleport on the next physics step, and until then a stale answer could hand
## out a false win.
func load_state(d: Dictionary) -> void:
	var list := objectives()
	for i in list.size():
		list[i].load_state(d["objectives"][i])
	_cut_off = false
	_in_extraction.clear()
	for unit in _tracked():
		if d["at_extraction"].has(String(unit.name)):
			_in_extraction[unit] = true
	var loaded := int(d["result"]) as Result
	if loaded != result:
		result = loaded
		result_changed.emit(result)


## The navmesh changes when a bridge breaks or a way is opened. From then on, anyone who cannot
## walk to the extraction never will.
func _on_nav_rebaked() -> void:
	if result != Result.RUNNING or _mission.extraction() == null:
		return
	var goal := _mission.extraction().global_position
	var map := _mission.nav_map()
	for s in _specialists:
		if not s.alive or is_at_extraction(s):
			continue
		var path := NavigationServer3D.map_get_path(map, s.global_position, goal, true)
		if path.is_empty() or Vector2(path[-1].x - goal.x, path[-1].z - goal.z).length() > REACH_TOLERANCE:
			_cut_off = true
			return


## Everyone whose being at the extraction matters.
func _tracked() -> Array[Unit]:
	var out: Array[Unit] = []
	for s in _specialists:
		out.append(s)
	if _mission:
		for p in _mission.prisoners():
			out.append(p)
	return out


func _adopt(o: Objective) -> void:
	o.setup(_mission, self)
	o.completed.connect(_on_completed.bind(o))


func _on_completed(o: Objective) -> void:
	objective_done.emit(o)


func _set_result(r: Result) -> void:
	result = r
	result_changed.emit(r)


func _on_specialist_died(_unit: Unit) -> void:
	# Left to the next evaluation so a same-frame detonation cannot sneak a win in first.
	pass


func _on_body_entered(body: Node3D) -> void:
	if body in _tracked():
		_in_extraction[body] = true


func _on_body_exited(body: Node3D) -> void:
	_in_extraction.erase(body)


func _on_node_added(node: Node) -> void:
	if node is PlantedCharge:
		_hook(node)


func _hook(charge: PlantedCharge) -> void:
	if not charge.detonated.is_connected(_on_detonated):
		charge.detonated.connect(_on_detonated)


## Every objective that is about a blast hears of it. The player is told a charge was wasted only
## when something was still to be destroyed and this blast destroyed none of it.
func _on_detonated(pos: Vector3) -> void:
	var waiting := 0
	var destroyed := 0
	for o in objectives():
		var destroy := o as DestroyObjective
		if destroy == null or destroy.done:
			continue
		waiting += 1
		destroy.on_detonated(pos)
		if destroy.done:
			destroyed += 1
	if waiting > 0 and destroyed == 0:
		charge_too_far.emit()
