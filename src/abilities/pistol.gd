class_name Pistol
extends Ability
## Ranged shot along the world-layer line of sight: a wall blocks it, no vision cone needed.
## Loud: announces itself on the NoiseBus.


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"pistol"
	ammo = tuning.pistol_ammo


func can_use(user: Specialist, target: Variant) -> bool:
	return _can_reach(user, target, tuning.pistol_range)


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	_spend_ammo()
	_announce(user, (target as Unit).global_position)
	NoiseBus.emit_noise(user.global_position, tuning.pistol_noise_radius)
	(target as Unit).take_damage(tuning.pistol_damage)
