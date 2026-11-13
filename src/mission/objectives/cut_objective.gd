class_name CutObjective
extends Objective
## Met when every one of its points has been cut, in any order. It never fails.

## The CutPoints, from the mission.
@export var points: Array[NodePath] = []


func point_nodes() -> Array[CutPoint]:
	var out: Array[CutPoint] = []
	if _mission == null:
		return out
	for path in points:
		var point := _mission.get_node_or_null(path) as CutPoint
		if point != null:
			out.append(point)
	return out


func points_left() -> int:
	var left := 0
	for point in point_nodes():
		if not point.cut:
			left += 1
	return left


func current_hud_text() -> String:
	return "%s: %d left" % [hud_text, points_left()]


## The pointer leads to the first point still whole.
func marker_position() -> Vector3:
	for point in point_nodes():
		if not point.cut:
			return point.global_position
	return Vector3.ZERO


func update() -> void:
	if not done and not points.is_empty() and point_nodes().size() == points.size() and points_left() == 0:
		complete()


func save_state() -> Dictionary:
	var d := super()
	var flags: Array[bool] = []
	for point in point_nodes():
		flags.append(point.cut)
	d["cut"] = flags
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	var nodes := point_nodes()
	for i in nodes.size():
		nodes[i].set_cut(bool(d["cut"][i]))


func state_ok(d: Variant) -> bool:
	if not super(d) or not d.get("cut") is Array or d["cut"].size() != point_nodes().size():
		return false
	for flag: Variant in d["cut"]:
		if not flag is bool:
			return false
	return true


func validate(mission: Mission, map: RID, from: Vector3) -> PackedStringArray:
	var errors := PackedStringArray()
	if points.is_empty():
		errors.append("%s: there is nothing to cut" % name)
	for path in points:
		var point := mission.get_node_or_null(path) as CutPoint
		if point == null:
			errors.append("%s: there is no cut point at %s" % [name, path])
			continue
		if not map.is_valid():
			errors.append("%s: nobody can stand at %s" % [name, point.name])
			continue
		var stand := NavigationServer3D.map_get_closest_point(map, point.global_position)
		if Vector2(stand.x - point.global_position.x, stand.z - point.global_position.z).length() > point.reach:
			errors.append("%s: nobody can stand at %s" % [name, point.name])
		elif not MissionValidator.reaches(map, from, stand):
			errors.append("%s: %s cannot be got to from the specialist spawn" % [name, point.name])
	return errors
