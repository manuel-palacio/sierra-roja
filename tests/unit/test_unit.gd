extends GutTest

var mission: Mission
var unit: Specialist
var noises: Array = []


func before_each() -> void:
	mission = load("res://scenes/missions/bridge.tscn").instantiate()
	# These tests are about one unit; live guards could shoot it.
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	unit = load("res://scenes/units/specialist.tscn").instantiate()
	unit.stats = load("res://resources/dynamiter.tres")
	add_child_autofree(unit)
	unit.global_position = mission.specialist_spawns()[0].global_position
	unit.set_nav_map(mission.nav_map())
	noises.clear()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _speed_over(frames: int) -> float:
	var start := unit.global_position
	await _frames(frames)
	return start.distance_to(unit.global_position) / (frames * get_physics_process_delta_time())


func test_walk_speed() -> void:
	unit.move_to(unit.global_position + Vector3(20, 0, 0))
	await _frames(5)
	assert_almost_eq(await _speed_over(60), 3.0, 0.3)


func test_run_speed() -> void:
	unit.move_to(unit.global_position + Vector3(25, 0, 0), true)
	await _frames(5)
	assert_almost_eq(await _speed_over(60), 6.0, 0.6)


func test_crawl_cannot_run() -> void:
	unit.set_stance(Unit.Stance.CRAWLING)
	unit.move_to(unit.global_position + Vector3(20, 0, 0), true)
	await _frames(5)
	assert_almost_eq(await _speed_over(60), 1.2, 0.12)


func test_can_run_false_walks() -> void:
	unit.can_run = false
	unit.move_to(unit.global_position + Vector3(20, 0, 0), true)
	await _frames(5)
	assert_almost_eq(await _speed_over(60), 3.0, 0.3)


func test_arrived_signal() -> void:
	watch_signals(unit)
	unit.move_to(unit.global_position + Vector3(3, 0, 0), true)
	await wait_for_signal(unit.arrived, 3.0)
	assert_signal_emitted(unit, "arrived")


func test_unreachable_goes_to_nearest() -> void:
	var target := Vector3(-36, 0, -120)
	var nearest := NavigationServer3D.map_get_closest_point(mission.nav_map(), target)
	unit.move_to(target, true)
	await wait_for_signal(unit.arrived, 15.0)
	assert_lt(unit.global_position.distance_to(nearest), 1.0)


func test_dead_ignores_orders() -> void:
	watch_signals(unit)
	unit.take_damage(100)
	assert_false(unit.alive)
	assert_signal_emitted(unit, "died")
	var start := unit.global_position
	unit.move_to(start + Vector3(10, 0, 0))
	await _frames(20)
	assert_eq(unit.global_position, start)


func test_damage_reduces_hp() -> void:
	unit.take_damage(30)
	assert_eq(unit.hp, 70)
	assert_true(unit.alive)


func test_running_emits_noise() -> void:
	NoiseBus.noise_emitted.connect(func(pos: Vector3, radius: float) -> void: noises.append([pos, radius]))
	unit.move_to(unit.global_position + Vector3(25, 0, 0), true)
	await wait_seconds(1.3)
	assert_gte(noises.size(), 2)
	assert_eq(noises[0][1], 8.0)


func test_walking_is_silent() -> void:
	NoiseBus.noise_emitted.connect(func(pos: Vector3, radius: float) -> void: noises.append(radius))
	unit.move_to(unit.global_position + Vector3(10, 0, 0))
	await wait_seconds(1.0)
	assert_eq(noises.size(), 0)


func _count_noise(_pos: Vector3, _radius: float) -> void:
	noises.append(_radius)


func test_zero_noise_radius_makes_no_noise() -> void:
	unit.stats = unit.stats.duplicate()
	unit.stats.run_noise_radius = 0.0
	NoiseBus.noise_emitted.connect(_count_noise)
	unit.move_to(unit.global_position + Vector3(25, 0, 0), true)
	await _frames(40)
	NoiseBus.noise_emitted.disconnect(_count_noise)
	assert_eq(noises.size(), 0)


func test_fixture_guards_are_disabled() -> void:
	for guard in mission.guards():
		assert_false(guard.can_process())


func test_specialist_joins_group() -> void:
	assert_true(unit.is_in_group(Specialist.GROUP))


func test_body_joins_group() -> void:
	var body: Body = load("res://scenes/units/body.tscn").instantiate()
	add_child_autofree(body)
	assert_true(body.is_in_group(Body.GROUP))


func test_save_load_roundtrip() -> void:
	unit.global_position = Vector3(-30, 0, 1)
	unit.rotation.y = 1.25
	unit.set_stance(Unit.Stance.CRAWLING)
	unit.take_damage(40)
	var d := unit.save_state()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var other: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	other.stats = load("res://resources/dynamiter.tres")
	add_child_autofree(other)
	other.load_state(parsed)
	assert_almost_eq(other.global_position, Vector3(-30, 0, 1), Vector3.ONE * 0.001)
	assert_almost_eq(other.rotation.y, 1.25, 0.001)
	assert_eq(other.stance, Unit.Stance.CRAWLING)
	assert_eq(other.hp, 60)
	assert_true(other.alive)


func test_save_load_dead() -> void:
	unit.take_damage(100)
	var other: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	other.stats = load("res://resources/dynamiter.tres")
	add_child_autofree(other)
	other.load_state(unit.save_state())
	assert_false(other.alive)
	assert_eq(other.hp, 0)


func test_body_defaults() -> void:
	var body: Body = load("res://scenes/units/body.tscn").instantiate()
	add_child_autofree(body)
	assert_false(body.found)
	assert_null(body.carried_by)


func test_marksman_resource() -> void:
	var s: Stats = load("res://resources/marksman.tres")
	assert_eq(s.walk_speed, 3.0)
	assert_eq(s.max_hp, 100)
