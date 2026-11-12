class_name RescueObjective
extends Objective
## Met when the prisoner stands at the extraction. First someone has to open his cell: from then
## on he follows whoever did. It fails the moment he dies.

const KILLED_TEXT := "The prisoner was killed"

## The Prisoner and the CellDoor, from the mission.
@export var prisoner: NodePath
@export var door: NodePath
## What the HUD says once the door is open.
@export var escort_text := "Bring the prisoner to the extraction point"


func setup(mission: Mission, rules: MissionRules) -> void:
	super(mission, rules)
	var cell := door_node()
	if cell != null and not cell.opened.is_connected(_on_opened):
		cell.opened.connect(_on_opened)


func prisoner_node() -> Prisoner:
	return _mission.get_node_or_null(prisoner) as Prisoner if _mission else null


func door_node() -> CellDoor:
	return _mission.get_node_or_null(door) as CellDoor if _mission else null


## What the HUD says: the way in until the door is open, then the way out.
func current_hud_text() -> String:
	var cell := door_node()
	return escort_text if cell != null and cell.open else hud_text


func current_marker_name() -> String:
	var cell := door_node()
	return ObjectiveMarker.EXTRACTION_TEXT if cell != null and cell.open else marker_name


func marker_position() -> Vector3:
	var cell := door_node()
	if cell == null:
		return Vector3.ZERO
	if cell.open and _mission.extraction() != null:
		var out := _mission.extraction().global_position
		return Vector3(out.x, _mission.ground_height(out.x, out.z), out.z)
	return cell.global_position


func update() -> void:
	var held := prisoner_node()
	if held == null:
		return
	if not held.alive:
		failed = true
	elif _rules != null and _rules.is_at_extraction(held):
		complete()


func fail_reason() -> String:
	return KILLED_TEXT if failed else ""


func save_state() -> Dictionary:
	var d := super()
	var cell := door_node()
	d["door_open"] = cell != null and cell.open
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	var cell := door_node()
	if cell != null:
		cell.set_open(bool(d["door_open"]))


func state_ok(d: Variant) -> bool:
	return super(d) and d.get("door_open") is bool


func validate(mission: Mission, map: RID, from: Vector3) -> PackedStringArray:
	var errors := PackedStringArray()
	var held := mission.get_node_or_null(prisoner) as Prisoner
	var cell := mission.get_node_or_null(door) as CellDoor
	if held == null:
		errors.append("%s: there is no prisoner" % name)
	if cell == null:
		errors.append("%s: the cell has no door" % name)
		return errors
	var stand := cell.stand_point()
	if not MissionValidator.reaches(map, from, stand):
		errors.append("%s: nobody can stand at the cell door" % name)
	elif mission.extraction() != null and not MissionValidator.reaches(map, stand, mission.extraction().global_position):
		errors.append("%s: the extraction is unreachable from the cell door" % name)
	return errors


func _on_opened(user: Specialist) -> void:
	var held := prisoner_node()
	if held != null and held.alive:
		held.follow(user)
