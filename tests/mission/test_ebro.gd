extends GutTest
## The Ebro: a sound map by night, three sentries apart on the bank, a river nobody walks, and
## boats that wait for the bank to be quiet.

const SCENE := "res://scenes/missions/ebro.tscn"
const BridgeBot := preload("res://tests/run/bridge_bot.gd")

var mission: Mission
var _clock := BridgeBot.FastClock.new()


func after_each() -> void:
	_clock.release()
	get_tree().paused = false


func _built(live_guards := false) -> Mission:
	mission = load(SCENE).instantiate()
	if not live_guards:
		mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().physics_frame
	mission.build_nav()
	await wait_physics_frames(2)
	return mission


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z), p.z)


func _reaches(from: Vector3, to: Vector3) -> bool:
	return MissionValidator.reaches(mission.nav_map(), _on_ground(from), _on_ground(to))


func _silence() -> SilenceObjective:
	return mission.objectives()[0] as SilenceObjective


func test_validator_passes() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_it_is_a_summer_night_with_eight_guards_and_a_searchlight() -> void:
	await _built()
	assert_true(mission.night)
	assert_eq(mission.season, &"summer")
	assert_eq(mission.dress, &"")
	assert_eq(mission.guards().size(), 8)
	var towers := 0
	for node in mission.find_children("*", "StaticBody3D", true, false):
		if node is Watchtower:
			towers += 1
			assert_not_null((node as Watchtower).searchlight)
	assert_eq(towers, 1)
	assert_eq(mission.title, "The crossing")


func test_the_objective_is_three_sentries_and_five_minutes() -> void:
	await _built()
	assert_eq(mission.objectives().size(), 1)
	var silence := _silence()
	assert_not_null(silence)
	assert_eq(silence.sentries.size(), 3)
	assert_eq(silence.seconds, 300.0)
	assert_eq(silence.sentries_left(), 3, "each name is a living guard of the mission")


func test_the_sentries_stand_apart() -> void:
	await _built()
	var beats: Array = []
	for sentry in _silence().sentries:
		beats.append(mission.guard_route(sentry))
	for i in beats.size():
		for j in range(i + 1, beats.size()):
			for a: Vector3 in beats[i]:
				for b: Vector3 in beats[j]:
					assert_gt(BridgeBot.flat(a, b), 15.0, "a body at the end of one beat is out of sight from the next")


func test_navmesh_is_well_inside_the_path_search_limit() -> void:
	await _built()
	var navmesh := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh
	assert_gt(navmesh.get_polygon_count(), 100)
	assert_lt(navmesh.get_polygon_count(), 2500)


func test_the_river_cannot_be_walked() -> void:
	await _built()
	for x in [-45.0, 0.0, 30.0]:
		var wet := Vector3(x, 0.0, -40.0)
		var nearest := NavigationServer3D.map_get_closest_point(mission.nav_map(), wet)
		assert_gt(Vector2(nearest.x - wet.x, nearest.z - wet.z).length(), 3.0, "x %s" % x)
	assert_not_null(mission.get_node_or_null("Scenery/Water"))


func test_nobody_sees_the_start_in_the_first_twenty_seconds() -> void:
	await _built(true)
	var specs := mission.spawn_specialists()
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	_clock.engage()
	for i in 20 * 60:
		await get_tree().physics_frame
	for guard in mission.guards():
		assert_eq(guard.brain.state, GuardBrain.State.PATROL, String(guard.name))
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_almost_eq(_silence().time_left, 280.0, 1.0, "and the clock has been running")


func test_each_post_can_be_walked_to_from_the_start_and_from_the_one_before() -> void:
	await _built()
	var from := mission.specialist_spawns()[0].global_position
	for sentry in _silence().sentries:
		var end: Vector3 = mission.guard_route(sentry)[1]
		assert_true(_reaches(from, end), sentry)
		from = end
	assert_true(_reaches(from, mission.extraction().global_position), "and from the last to the landing")


func test_the_landing_is_at_the_foot_of_the_bank() -> void:
	await _built()
	var out := mission.extraction().global_position
	assert_lt(mission.ground_height(out.x, out.z), 1.8)
	assert_true(_reaches(mission.specialist_spawns()[0].global_position, out))


func test_boats_wait_on_the_far_side_until_the_bank_is_quiet() -> void:
	await _built()
	var crossing := mission.get_node("Scenery/Crossing") as BoatCrossing
	assert_eq(crossing.boats().size(), 4)
	assert_false(crossing.crossing)
	for boat in crossing.boats():
		assert_lt(boat.global_position.z, -80.0, "out of sight beyond the north edge")
	_silence().complete()
	assert_true(crossing.crossing)
	crossing.arrive()
	for boat in crossing.boats():
		assert_between(boat.global_position.z, -34.0, -30.0)
