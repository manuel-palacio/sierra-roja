class_name Ability
extends RefCounted
## A specialist's skill. Subclasses set `id` and implement can_use/use. `ammo` -1 is unlimited.
## Rules only: nothing here draws anything.

var id := &""
var ammo := -1
var tuning: AbilityTuning


func _init(t: AbilityTuning = null) -> void:
	tuning = t if t != null else AbilityTuning.defaults()


func can_use(_user: Specialist, _target: Variant) -> bool:
	return false


func use(_user: Specialist, _target: Variant) -> void:
	pass


## False while the ability cannot be used at all for now, whatever the target.
func ready_to_use() -> bool:
	return ammo != 0


## Time passing for the one who has it (see Specialist).
func tick(_delta: float) -> void:
	pass


## JSON-safe snapshot. The ability set itself is rebuilt from ids by AbilityKit.
func save_state() -> Dictionary:
	return { "id": String(id), "ammo": ammo }


func load_state(d: Dictionary) -> void:
	ammo = int(d["ammo"])


func _user_ready(user: Specialist) -> bool:
	return user != null and is_instance_valid(user) and user.alive and user.is_inside_tree()


## A live Guard, or null. Knife and firearms only ever target guards.
func _unit_target(_user: Specialist, target: Variant) -> Guard:
	if typeof(target) != TYPE_OBJECT or target == null or not is_instance_valid(target):
		return null
	var unit := target as Guard
	if unit == null or not unit.alive or not unit.is_inside_tree():
		return null
	return unit


## In range of a live target with an unobstructed world-layer ray (walls block, units do not).
func _can_reach(user: Specialist, target: Variant, range_m: float) -> bool:
	if not _user_ready(user) or ammo == 0:
		return false
	var unit := _unit_target(user, target)
	if unit == null or user.global_position.distance_to(unit.global_position) > range_m:
		return false
	return Perception.line_clear(user,
			user.global_position + Vector3.UP * tuning.shot_origin_height,
			unit.global_position + Vector3.UP * tuning.shot_target_height)


## The user turns to where it is striking and lets it be seen and heard.
func _announce(user: Specialist, at: Vector3) -> void:
	user.face(at)
	user.acted.emit(id, at)


func _spend_ammo() -> void:
	if ammo > 0:
		ammo -= 1
