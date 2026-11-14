class_name Stone
extends Ability
## A stone thrown to a spot (Vector3) in range with a clear line. It lands with a small noise
## that brings the guards in earshot to look, and harms nobody. Never runs out, but the next
## one takes a moment to find.

## Seconds until another can be thrown.
var cooldown_left := 0.0


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"stone"


func can_use(user: Specialist, target: Variant) -> bool:
	if not _user_ready(user) or cooldown_left > 0.0 or typeof(target) != TYPE_VECTOR3:
		return false
	var spot := target as Vector3
	if user.global_position.distance_to(spot) > tuning.stone_range:
		return false
	return Perception.line_clear(user,
			user.global_position + Vector3.UP * tuning.shot_origin_height,
			spot + Vector3.UP * tuning.stone_landing_height)


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	cooldown_left = tuning.stone_cooldown
	_announce(user, target as Vector3)
	NoiseBus.emit_noise(target as Vector3, tuning.stone_noise_radius)


func ready_to_use() -> bool:
	return cooldown_left <= 0.0


func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)


func save_state() -> Dictionary:
	var d := super()
	d["cooldown"] = cooldown_left
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	cooldown_left = float(d.get("cooldown", 0.0))
