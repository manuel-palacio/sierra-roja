class_name Carry
extends Ability
## Picks up a body within range, or (with a null target) drops the one being carried.
## While carrying, the user can only walk.


func _init(t: AbilityTuning = null) -> void:
	super(t)
	id = &"carry"


func can_use(user: Specialist, target: Variant) -> bool:
	if not _user_ready(user) or user.holding != null:
		return false
	if user.carrying != null:
		return target == null
	if typeof(target) != TYPE_OBJECT or target == null or not is_instance_valid(target):
		return false
	var body := target as Body
	return body != null and body.is_inside_tree() and body.carried_by == null and not body.hidden \
			and user.global_position.distance_to(body.global_position) <= tuning.pickup_range


func use(user: Specialist, target: Variant) -> void:
	if not can_use(user, target):
		return
	if user.carrying != null:
		user.drop_body()
	else:
		user.pick_up(target as Body)
