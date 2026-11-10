class_name Knife
extends Ability
## Silent kill at arm's length. Needs range and a clear line, not a vision cone.


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"knife"


func can_use(user: Specialist, target: Variant) -> bool:
	return _can_reach(user, target, tuning.knife_range)


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	_announce(user, (target as Unit).global_position)
	(target as Unit).take_damage(tuning.knife_damage)
