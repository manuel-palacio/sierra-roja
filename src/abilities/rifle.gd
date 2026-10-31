class_name Rifle
extends Ability
## Ranged shot along the world-layer line of sight: a wall blocks it, no vision cone needed.
## Loud: announces itself on the NoiseBus.


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"rifle"
	ammo = tuning.rifle_ammo


func can_use(user: Specialist, target: Variant) -> bool:
	return _can_reach(user, target, tuning.rifle_range)


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	_spend_ammo()
	NoiseBus.emit_noise(user.global_position, tuning.rifle_noise_radius)
	(target as Unit).take_damage(tuning.rifle_damage)
