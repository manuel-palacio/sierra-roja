extends GutTest

const EYE := Vector3(0, 1.6, 0)
const FWD := Vector3(0, 0, -1)


func _zone(target: Vector3, stance: Unit.Stance, far := 14.0) -> Vision.Zone:
	return Vision.zone(EYE, FWD, target, stance, far)


func test_near_standing_and_crawling() -> void:
	assert_eq(_zone(Vector3(0, 1.5, -5), Unit.Stance.STANDING), Vision.Zone.NEAR)
	assert_eq(_zone(Vector3(0, 0.3, -5), Unit.Stance.CRAWLING), Vision.Zone.NEAR)


func test_far_standing_only() -> void:
	assert_eq(_zone(Vector3(0, 1.5, -10), Unit.Stance.STANDING), Vision.Zone.FAR)
	assert_eq(_zone(Vector3(0, 0.3, -10), Unit.Stance.CRAWLING), Vision.Zone.NONE)


func test_beyond_far_range_is_none() -> void:
	assert_eq(_zone(Vector3(0, 1.5, -15), Unit.Stance.STANDING), Vision.Zone.NONE)


func test_off_axis_is_none() -> void:
	assert_eq(_zone(Vector3(5, 1.5, 0), Unit.Stance.STANDING), Vision.Zone.NONE)
	assert_eq(_zone(Vector3(0, 1.5, 5), Unit.Stance.STANDING), Vision.Zone.NONE)


func test_inside_half_angle_is_seen() -> void:
	# 30 degrees off axis at 10 m
	var t := Vector3(sin(deg_to_rad(30.0)) * 10.0, 1.5, -cos(deg_to_rad(30.0)) * 10.0)
	assert_eq(_zone(t, Unit.Stance.STANDING), Vision.Zone.FAR)


func test_alarm_far_range_extends_far_zone() -> void:
	assert_eq(_zone(Vector3(0, 1.5, -16), Unit.Stance.STANDING, 18.0), Vision.Zone.FAR)


func test_tuning_comes_from_resource() -> void:
	var v: GuardVision = load("res://resources/guard_vision.tres")
	assert_eq(v.near_range, 6.0)
	assert_eq(v.far_range, 14.0)
	assert_eq(v.alarm_far_range, 18.0)
	assert_eq(v.half_angle_deg, 40.0)
	assert_eq(v.eye_height, 1.6)
	assert_eq(v.target_height(Unit.Stance.STANDING), 1.5)
	assert_eq(v.target_height(Unit.Stance.CRAWLING), 0.3)
