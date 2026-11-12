extends GutTest
## Guards, searchlights and blasts go for everyone in the hunted group, not only the specialists.

var guard: Guard


func before_each() -> void:
	guard = load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(guard)
	guard.global_position = Vector3.ZERO


func _ahead(metres: float) -> Vector3:
	return guard.global_position - guard.global_basis.z * metres


func _unit(pos: Vector3) -> Unit:
	var unit := Unit.new()
	add_child_autofree(unit)
	unit.global_position = pos
	return unit


func test_specialists_are_hunted() -> void:
	var s := load("res://scenes/units/specialist.tscn").instantiate() as Specialist
	add_child_autofree(s)
	assert_true(s.is_in_group(Unit.HUNTED))


func test_guard_sees_any_hunted_unit() -> void:
	var unit := _unit(_ahead(6.0))
	unit.add_to_group(Unit.HUNTED)
	await wait_physics_frames(2)
	var seen := guard._strongest_target()
	assert_ne(seen["zone"], Vision.Zone.NONE)
	assert_eq(seen["specialist"], unit)


func test_guard_ignores_a_unit_that_is_not_hunted() -> void:
	_unit(_ahead(6.0))
	await wait_physics_frames(2)
	assert_eq(guard._strongest_target()["zone"], Vision.Zone.NONE)


func test_a_blast_kills_any_hunted_unit() -> void:
	var unit := _unit(Vector3(30, 0, 30))
	unit.add_to_group(Unit.HUNTED)
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	add_child_autofree(charge)
	charge.global_position = Vector3(31, 0, 30)
	charge.advance(0.1)
	assert_false(unit.alive)
