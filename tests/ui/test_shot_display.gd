extends GutTest
## A shot is seen: a streak from the muzzle to the target and a flash, both gone in a moment.

var display: ShotDisplay


func before_each() -> void:
	display = ShotDisplay.new()
	add_child_autofree(display)


func _unit(scene: String, at: Vector3) -> Unit:
	var unit: Unit = load(scene).instantiate()
	add_child_autofree(unit)
	unit.set_physics_process(false)
	unit.global_position = at
	return unit


func test_a_rifle_shot_draws_a_streak_from_shooter_to_target() -> void:
	var shooter := _unit("res://scenes/units/marksman.tscn", Vector3(0, 0, 0))
	await get_tree().process_frame
	shooter.acted.emit(&"rifle", Vector3(0, 0, -20))
	assert_eq(display.streaks.size(), 1)
	var streak := display.streaks[0]
	assert_almost_eq(streak.global_position.x, 0.0, 0.01)
	assert_between(streak.global_position.z, -12.0, -8.0, "midway between the two")
	assert_between(streak.global_position.y, 0.8, 2.0, "at chest height")
	assert_almost_eq(display.streak_length(streak), 20.0, 1.5)
	assert_eq(display.flashes.size(), 1)
	assert_lt(display.flashes[0].global_position.distance_to(shooter.global_position + Vector3.UP * 1.4), 1.5,
			"the flash is at the shooter")


func test_streak_and_flash_are_gone_in_a_moment() -> void:
	var shooter := _unit("res://scenes/units/marksman.tscn", Vector3.ZERO)
	await get_tree().process_frame
	shooter.acted.emit(&"pistol", Vector3(5, 0, 0))
	display._process(ShotDisplay.FLASH_SECONDS + 0.01)
	assert_eq(display.flashes.size(), 0)
	assert_eq(display.streaks.size(), 1)
	display._process(ShotDisplay.STREAK_SECONDS)
	assert_eq(display.streaks.size(), 0)
	await get_tree().process_frame
	assert_eq(display.get_child_count(), 0)


func test_a_knife_draws_nothing() -> void:
	var dynamiter := _unit("res://scenes/units/specialist.tscn", Vector3.ZERO)
	await get_tree().process_frame
	dynamiter.acted.emit(&"knife", Vector3(1, 0, 0))
	assert_eq(display.streaks.size(), 0)
	assert_eq(display.flashes.size(), 0)


func test_units_that_arrive_later_are_shown_too() -> void:
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(3, 0, 3))
	await get_tree().process_frame
	await get_tree().process_frame
	guard.acted.emit(&"rifle", Vector3(3, 0, -5))
	assert_eq(display.streaks.size(), 1)
