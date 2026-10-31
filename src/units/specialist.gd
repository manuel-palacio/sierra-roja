class_name Specialist
extends Unit
## A player-controlled operative. `ability_ids` is what scenes configure per specialist
## (Dynamiter: knife, charge, pistol, carry; Marksman: rifle, pistol); they are built at spawn.

const GROUP := "specialists"

@export var ability_ids := PackedStringArray()
## Ability id (String) -> Ability.
var abilities: Dictionary = {}
var carrying: Body

var _can_run_before_carry := true


func _ready() -> void:
	super()
	add_to_group(GROUP)
	died.connect(_on_died)
	if abilities.is_empty():
		grant_abilities(ability_ids)


func grant_abilities(ids: PackedStringArray) -> void:
	for id in ids:
		abilities[id] = AbilityKit.create(id)


func has_ability(id: String) -> bool:
	return abilities.has(id)


## Picks up a body; carrying forces walking until it is dropped.
func pick_up(body: Body) -> void:
	if carrying != null:
		return
	carrying = body
	body.carried_by = self
	body.global_position = global_position
	_can_run_before_carry = can_run
	can_run = false
	_running = false


## Puts the carried body down where the carrier stands and lets them run again.
func drop_body() -> void:
	if carrying == null:
		return
	if is_instance_valid(carrying):
		carrying.carried_by = null
		carrying.global_position = global_position
	carrying = null
	can_run = _can_run_before_carry


func _on_died(_unit: Unit) -> void:
	drop_body()
