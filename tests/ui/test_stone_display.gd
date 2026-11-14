extends GutTest
## A thrown stone is seen: a pebble in an arc from the thrower to where it lands, then gone.

var display: StoneDisplay


func before_each() -> void:
	display = StoneDisplay.new()
	add_child_autofree(display)


func test_a_stone_flies_in_an_arc_and_is_gone_when_it_lands() -> void:
	var thrower: Specialist = load("res://scenes/units/marksman.tscn").instantiate()
	add_child_autofree(thrower)
	thrower.set_physics_process(false)
	await get_tree().process_frame
	thrower.acted.emit(&"stone", Vector3(0, 0, -10))
	assert_eq(display.stones.size(), 1)
	display._process(StoneDisplay.FLIGHT_SECONDS / 2.0)
	var stone := display.stones[0]
	assert_almost_eq(stone.global_position.z, -5.0, 0.1, "half way there")
	assert_gt(stone.global_position.y, 2.0, "and high in the air")
	display._process(StoneDisplay.FLIGHT_SECONDS)
	assert_eq(display.stones.size(), 0)


func test_a_shot_throws_no_stone() -> void:
	var shooter: Specialist = load("res://scenes/units/marksman.tscn").instantiate()
	add_child_autofree(shooter)
	await get_tree().process_frame
	shooter.acted.emit(&"rifle", Vector3(0, 0, -10))
	assert_eq(display.stones.size(), 0)
