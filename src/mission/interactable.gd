class_name Interactable
extends Node3D
## Something a specialist standing next to it can use with F: a cell door, papers to take, a
## telephone line to cut. What using it does is the subclass's business.

const GROUP := "interactables"

## How close, on the ground plane, the user has to stand.
@export var reach := 1.8
## Said to the player when it is used; "" says nothing.
@export var prompt := ""
## False once there is nothing more to do with it.
var usable := true


func _ready() -> void:
	add_to_group(GROUP)


func can_interact(user: Specialist) -> bool:
	if not usable or user == null or not user.alive:
		return false
	var away := Vector2(user.global_position.x - global_position.x, user.global_position.z - global_position.z)
	return away.length() <= reach


func interact(_user: Specialist) -> void:
	pass


## The closest thing this specialist can use where they stand; null when there is none.
static func nearest(tree: SceneTree, user: Specialist) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for node in tree.get_nodes_in_group(GROUP):
		var thing := node as Interactable
		if thing == null or not thing.can_interact(user):
			continue
		var d := thing.global_position.distance_to(user.global_position)
		if d < best_distance:
			best_distance = d
			best = thing
	return best
