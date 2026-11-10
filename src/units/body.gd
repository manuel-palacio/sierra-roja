class_name Body
extends Node3D
## A downed guard. Guards find it (found); a Dynamiter can carry it (carried_by), and while
## carried it follows the carrier. Dropped, it stays where it lies and stays discoverable.

const GROUP := "bodies"
const SCENE := "res://scenes/units/body.tscn"
const KIT := &"guard"

## The uniform the guard wore.
@export var uniform: Texture2D

var found := false
## The carrier, or null.
var carried_by: Specialist
## The guard this was, which is what identifies it in a save.
var save_id := ""


func _ready() -> void:
	add_to_group(GROUP)
	var model := get_node_or_null("Model")
	if model == null:
		return
	UnitVisual.dress(model, uniform)
	SoldierGear.equip(model, KIT)
	# The guard as it fell: the last frame of its death, held.
	for node in model.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		if player.has_animation(UnitVisual.DIE):
			player.play(UnitVisual.DIE)
			player.seek(player.current_animation_length, true)
			player.pause()


func _physics_process(_delta: float) -> void:
	if carried_by != null:
		if is_instance_valid(carried_by):
			global_position = carried_by.global_position
		else:
			carried_by = null


## JSON-safe snapshot. "carrier" is the carrier's save id, the Unit's name ("" when lying down).
func save_state() -> Dictionary:
	var carrier := ""
	if carried_by != null and is_instance_valid(carried_by):
		carrier = String(carried_by.name)
	return {
		"id": save_id,
		"pos": [global_position.x, global_position.y, global_position.z],
		"rot": rotation.y,
		"found": found,
		"carrier": carrier,
	}


## Restores everything but the carrier, which is left to the loader: find the Specialist named
## by "carrier" and call Specialist.pick_up(body).
func load_state(d: Dictionary) -> void:
	save_id = String(d["id"])
	var p: Array = d["pos"]
	global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(d["rot"])
	found = bool(d["found"])
	carried_by = null
