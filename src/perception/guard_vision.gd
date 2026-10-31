class_name GuardVision
extends Resource
## Tuning for what a guard can see. Lives in resources/guard_vision.tres so balance needs no code.

@export var near_range := 6.0
@export var far_range := 14.0
## Far range once an alarm has been raised.
@export var alarm_far_range := 18.0
@export var half_angle_deg := 40.0
@export var eye_height := 1.6
@export var target_height_standing := 1.5
@export var target_height_crawling := 0.3


func target_height(stance: Unit.Stance) -> float:
	return target_height_crawling if stance == Unit.Stance.CRAWLING else target_height_standing
