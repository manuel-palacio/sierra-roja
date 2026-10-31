class_name Body
extends Node3D
## A downed guard. Guards find it (found); a Dynamiter can carry it (carried_by), and while
## carried it follows the carrier. Dropped, it stays where it lies and stays discoverable.

const GROUP := "bodies"
const SCENE := "res://scenes/units/body.tscn"

var found := false
## The carrier, or null. Task 11 saves a stable reference (e.g. the carrier's save id) via
## save_state's "carried" flag and resolves it on load.
var carried_by: Specialist


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	if carried_by != null:
		if is_instance_valid(carried_by):
			global_position = carried_by.global_position
		else:
			carried_by = null


## JSON-safe snapshot. "carrier_path" is the carrier's path in the scene tree ("" when lying
## down); Task 11 swaps it for a save id if it wants one.
func save_state() -> Dictionary:
	var carrier_path := ""
	if carried_by != null and is_instance_valid(carried_by) and carried_by.is_inside_tree():
		carrier_path = String(carried_by.get_path())
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"found": found,
		"carrier_path": carrier_path,
	}


## Restores position and found. The carrier is left to the loader: read "carrier_path" from
## the saved dictionary, find the Specialist, and call Specialist.pick_up(body).
func load_state(d: Dictionary) -> void:
	var p: Array = d["pos"]
	global_position = Vector3(p[0], p[1], p[2])
	found = bool(d["found"])
	carried_by = null
