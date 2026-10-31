class_name Charge
extends Ability
## Plants a timed charge. The target is the spot (Vector3) within plant range; null plants
## at the user's feet. Limited by charge_count.


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"charge"
	ammo = tuning.charge_count


func can_use(user: Specialist, target: Variant) -> bool:
	if not _user_ready(user) or ammo == 0 or user.get_parent() == null:
		return false
	if not _valid_spot(target):
		return false
	return user.global_position.distance_to(_spot(user, target)) <= tuning.plant_range


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	_spend_ammo()
	var planted := PlantedCharge.new()
	planted.tuning = tuning
	planted.fuse_left = tuning.charge_fuse
	user.get_parent().add_child(planted)
	planted.global_position = _spot(user, target)


func _valid_spot(target: Variant) -> bool:
	return target == null or typeof(target) == TYPE_VECTOR3


func _spot(user: Specialist, target: Variant) -> Vector3:
	return user.global_position if target == null else target as Vector3
