extends GutTest
## The Volkhov: a sound map in snow at dusk, a river of ice that can be walked, and orders to take.

const SCENE := "res://scenes/missions/volkhov.tscn"
const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const DOOR := Vector3(30, 0, -1.8)

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


func _way(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(mission.nav_map(), _on_ground(from), _on_ground(to), true)
	var total := 0.0
	for i in range(1, path.size()):
		total += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	return total


func test_validator_passes() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_it_is_a_winter_dusk_with_seven_guards_in_blue() -> void:
	await _built()
	assert_eq(mission.season, &"snow")
	assert_eq(mission.light, &"dusk")
	assert_false(mission.night)
	assert_true(mission.snowfall)
	assert_eq(mission.dress, &"russia")
	assert_eq(mission.guards().size(), 7)
	assert_eq(mission.title, "The orders")
	assert_eq(mission.briefing_lines.size(), 3)


func test_the_objective_is_to_steal_the_orders() -> void:
	await _built()
	assert_eq(mission.objectives().size(), 1)
	var steal := mission.objectives()[0] as StealObjective
	assert_not_null(steal)
	assert_not_null(steal.item_node())
	assert_eq(steal.hud_text, "Take the orders from the command post")


func test_navmesh_is_well_inside_the_path_search_limit() -> void:
	await _built()
	var navmesh := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh
	assert_gt(navmesh.get_polygon_count(), 100)
	assert_lt(navmesh.get_polygon_count(), 2500)


func test_the_ice_can_be_walked_bank_to_bank() -> void:
	await _built()
	for z in [-10.0, 0.0, 15.0, 32.0]:
		var west := Vector3(-11, 0, z)
		var east := Vector3(12, 0, z)
		assert_true(_reaches(west, east), "at z %s" % z)
		assert_lt(_way(west, east), 23.0 * 1.3, "straight over at z %s, not round" % z)


func test_each_way_over_reaches_the_command_post_door() -> void:
	await _built()
	var spawn := mission.specialist_spawns()[0].global_position
	var ways := {
		"the open ice": [Vector3(-11, 0, 0), Vector3(12, 0, 0)],
		"the causeway": [Vector3(-13, 0, -34), Vector3(13, 0, -34)],
		"the drifts": [Vector3(-12, 0, 33), Vector3(10, 0, 32)],
	}
	for way: String in ways:
		assert_true(_reaches(spawn, ways[way][0]), "%s can be got to" % way)
		assert_true(_reaches(ways[way][1], DOOR), "%s leads to the command post" % way)


func test_the_orders_can_be_reached_and_taken() -> void:
	await _built()
	var specs := mission.spawn_specialists()
	var item := (mission.objectives()[0] as StealObjective).item_node()
	assert_true(_reaches(DOOR, Vector3(item.global_position.x, 0, item.global_position.z)), "through the door to the table")
	specs[0].global_position = _on_ground(Vector3(item.global_position.x + 0.6, 0, item.global_position.z + 0.6))
	assert_eq(Interactable.nearest(get_tree(), specs[0]), item)
	item.interact(specs[0])
	assert_eq(item.carrier, specs[0])


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
	assert_eq(rules.alarm_level, 0)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_no_searchlight_and_no_watchtower_by_dusk() -> void:
	await _built()
	for node in mission.find_children("*", "StaticBody3D", true, false):
		assert_false(node is Watchtower)


func test_the_houses_are_of_logs_and_everything_wears_snow() -> void:
	await _built()
	var houses := 0
	for node in mission.find_children("*", "StaticBody3D", true, false):
		if node is Building:
			houses += 1
			assert_eq((node as Building).style, &"log", String(node.name))
			assert_true((node as Building).snowy, String(node.name))
	assert_eq(houses, 4)
