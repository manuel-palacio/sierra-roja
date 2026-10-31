class_name Body
extends Node3D
## A downed guard. Behaviour (discovery, carrying) comes in later tasks.

const GROUP := "bodies"

var found := false
var carried_by: Specialist


func _ready() -> void:
	add_to_group(GROUP)
