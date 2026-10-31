class_name Specialist
extends Unit
## A player-controlled operative. Abilities (name -> data) are filled in by later tasks.

const GROUP := "specialists"

var abilities: Dictionary = {}


func _ready() -> void:
	super()
	add_to_group(GROUP)
