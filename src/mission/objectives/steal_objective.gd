class_name StealObjective
extends Objective
## Met when a living specialist carrying the item stands at the extraction. The item lying there
## is not enough, and neither is having held it once. It cannot be destroyed, so this never fails.

## The Carryable, from the mission.
@export var item: NodePath
## What the HUD says while it is in someone's hands.
@export var carry_text := "Bring it out"


func item_node() -> Carryable:
	return _mission.get_node_or_null(item) as Carryable if _mission else null


func current_hud_text() -> String:
	var thing := item_node()
	return carry_text if thing != null and thing.carrier != null else hud_text


func current_marker_name() -> String:
	var thing := item_node()
	return ObjectiveMarker.EXTRACTION_TEXT if thing != null and thing.carrier != null else marker_name


func marker_position() -> Vector3:
	var thing := item_node()
	if thing == null:
		return Vector3.ZERO
	if thing.carrier != null and _mission.extraction() != null:
		var out := _mission.extraction().global_position
		return Vector3(out.x, _mission.ground_height(out.x, out.z), out.z)
	return thing.global_position


func update() -> void:
	var thing := item_node()
	if thing == null or thing.carrier == null or _rules == null:
		return
	if thing.carrier.alive and _rules.is_at_extraction(thing.carrier):
		complete()


func save_state() -> Dictionary:
	var d := super()
	var thing := item_node()
	var at := thing.global_position if thing != null else Vector3.ZERO
	d["carrier"] = String(thing.carrier.name) if thing != null and thing.carrier != null else ""
	d["pos"] = [at.x, at.y, at.z]
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	var thing := item_node()
	if thing == null:
		return
	var p: Array = d["pos"]
	thing.lie_at(Vector3(p[0], p[1], p[2]))
	if d["carrier"] != "":
		for s in _mission.specialists():
			if String(s.name) == d["carrier"]:
				thing.give_to(s)


func state_ok(d: Variant) -> bool:
	if not super(d) or not d.get("carrier") is String:
		return false
	var p: Variant = d.get("pos")
	if not p is Array or p.size() != 3:
		return false
	for n: Variant in p:
		if not (n is float or n is int) or not is_finite(float(n)):
			return false
	return true


## The carrier has to be one of the save's living specialists.
func state_ok_in(d: Variant, specialists: Array) -> bool:
	if not state_ok(d):
		return false
	if d["carrier"] == "":
		return true
	for s: Variant in specialists:
		if s is Dictionary and s.get("id") == d["carrier"]:
			return s.get("alive") == true
	return false


func validate(mission: Mission, map: RID, from: Vector3) -> PackedStringArray:
	var errors := PackedStringArray()
	var thing := mission.get_node_or_null(item) as Carryable
	if thing == null:
		errors.append("%s: there is nothing to take" % name)
		return errors
	if not map.is_valid():
		errors.append("%s: nobody can stand within reach of it" % name)
		return errors
	var stand := NavigationServer3D.map_get_closest_point(map, thing.global_position)
	if Vector2(stand.x - thing.global_position.x, stand.z - thing.global_position.z).length() > thing.reach:
		errors.append("%s: nobody can stand within reach of it" % name)
	elif not MissionValidator.reaches(map, from, stand):
		errors.append("%s: it cannot be got to from the specialist spawn" % name)
	return errors
