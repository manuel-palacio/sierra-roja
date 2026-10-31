class_name MissionRules
extends Node
## Win and loss for the bridge mission. Win: the bridge is destroyed and both specialists are
## alive inside Mission.extraction(). Loss: either specialist dies. The result is evaluated once
## per physics frame, loss first, and is final once it leaves RUNNING.
##
## Charges are created at runtime, so rules hook them through SceneTree.node_added (plus any
## already in the "charges" group). Neither the planting code nor save/load has to know about
## the rules; a charge restored by load_state hooks in as it enters the tree.

signal result_changed(result: Result)
signal bridge_blown()

enum Result { RUNNING, WON, LOST }

## A charge destroys the bridge when it goes off this close to Mission.bridge_target().
const BRIDGE_BLAST_RANGE := 8.0

var result := Result.RUNNING
var bridge_destroyed := false

var _mission: Mission
var _specialists: Array[Specialist] = []
var _in_extraction: Dictionary = {}  # Specialist -> true


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
	if not bridge_destroyed or _specialists.is_empty():
		return
	for s in _specialists:
		if not at_extraction(s):
			return
	_set_result(Result.WON)


func save_state() -> Dictionary:
	return { "result": int(result), "bridge_destroyed": bridge_destroyed }


## Restores a destroyed bridge too: the broken deck is rebuilt and the navmesh rebaked.
func load_state(d: Dictionary) -> void:
	bridge_destroyed = bool(d["bridge_destroyed"])
	if bridge_destroyed and _mission:
		_mission.break_bridge()
	var loaded := int(d["result"]) as Result
	if loaded != result:
		result = loaded
		result_changed.emit(result)


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
		return
	bridge_destroyed = true
	_mission.break_bridge()
	bridge_blown.emit()
