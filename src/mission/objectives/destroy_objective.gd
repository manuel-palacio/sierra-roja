class_name DestroyObjective
extends Objective
## Met when a charge goes off close enough to the target. The target goes with it: a bridge loses
## its span, and whoever stands on it; a stack of stores leaves the map.

## A charge went off while the target stood, too far away to destroy it.
signal charge_too_far()

## The Marker3D at the thing to destroy, from the mission.
@export var target: NodePath
## A charge destroys the target when it goes off this close to it.
@export var blast_range := 8.0


func target_node() -> Node3D:
	return _mission.get_node_or_null(target) as Node3D if _mission else null


func marker_position() -> Vector3:
	var node := target_node()
	return node.global_position if node else Vector3.ZERO


func on_detonated(pos: Vector3) -> void:
	var node := target_node()
	if done or node == null:
		return
	if pos.distance_to(node.global_position) > blast_range:
		charge_too_far.emit()
		return
	_drop_whoever_is_on_the_span()
	_mission.break_bridge()
	complete()


func load_state(d: Dictionary) -> void:
	super(d)
	if _mission == null:
		return
	if done:
		_mission.break_bridge()
	else:
		_mission.repair_bridge()


func validate(mission: Mission, map: RID, from: Vector3) -> PackedStringArray:
	var errors := PackedStringArray()
	var node := mission.get_node_or_null(target) as Node3D
	if node == null:
		errors.append("%s: target is missing" % name)
	elif not MissionValidator.reaches(map, from, node.global_position):
		errors.append("%s: target is unreachable from the specialist spawn" % name)
	return errors


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
