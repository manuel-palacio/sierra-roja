extends GutTest
## Fort Carchuna: the map is sound, dark, guarded, and can be got into three ways.

const SCENE := "res://scenes/missions/carchuna.tscn"
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


func _reaches(from: Vector3, to: Vector3) -> bool:
	return MissionValidator.reaches(mission.nav_map(), _on_ground(from), _on_ground(to))


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z), p.z)


## Length of the way from one point to another, on the ground plane.
func _way(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(mission.nav_map(), _on_ground(from), _on_ground(to), true)
	var total := 0.0
	for i in range(1, path.size()):
		total += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	return total


func test_validator_passes() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_it_is_a_night_mission_with_seven_guards_and_a_searchlight() -> void:
	await _built()
	assert_true(mission.night)
	assert_eq(mission.guards().size(), 7)
	var lights := mission.find_children("*", "Searchlight", true, false)
	assert_gt(lights.size(), 0)


func test_the_objective_is_a_rescue() -> void:
	await _built()
	assert_eq(mission.objectives().size(), 1)
	assert_true(mission.objectives()[0] is RescueObjective)
	assert_eq(mission.prisoners().size(), 1)
	assert_eq(mission.title, "Fort Carchuna")
	assert_eq(mission.briefing_lines.size(), 3)


func test_navmesh_is_well_inside_the_path_search_limit() -> void:
	await _built()
	var navmesh := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh
	assert_gt(navmesh.get_polygon_count(), 100)
	assert_lt(navmesh.get_polygon_count(), 2500)


func test_nobody_sees_the_start_or_the_cell_at_the_start() -> void:
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


func test_the_sea_cannot_be_walked() -> void:
	await _built()
	for x in [-45.0, -37.0, 0.0, 30.0]:
		var wet := Vector3(x, 0.0, 40.0)
		var nearest := NavigationServer3D.map_get_closest_point(mission.nav_map(), wet)
		assert_gt(Vector2(nearest.x - wet.x, nearest.z - wet.z).length(), 3.0, "x %s" % x)


func test_the_launch_is_on_the_beach_and_can_be_walked_to() -> void:
	await _built()
	var out := mission.extraction().global_position
	assert_lt(mission.ground_height(out.x, out.z), 1.6, "down on the beach")
	assert_true(_reaches(mission.specialist_spawns()[0].global_position, out))


func test_each_way_in_reaches_the_cell_door() -> void:
	await _built()
	var door := mission.get_node("CellDoor") as CellDoor
	var stand := door.stand_point()
	# Just outside and just inside each opening in the wall.
	var ways := {
		"gate": [Vector3(23, 0, -12.5), Vector3(23, 0, -7.5)],
		"breach": [Vector3(5.5, 0, 15.6), Vector3(10.5, 0, 15.6)],
		"postern": [Vector3(40.5, 0, 0.5), Vector3(35.5, 0, 0.5)],
	}
	var spawn := mission.specialist_spawns()[0].global_position
	for way: String in ways:
		var outside: Vector3 = ways[way][0]
		var inside: Vector3 = ways[way][1]
		assert_true(_reaches(spawn, outside), "%s can be got to" % way)
		assert_true(_reaches(inside, stand), "%s leads to the cells" % way)
		assert_lt(_way(outside, inside), 9.0, "%s is a way through the wall, not round it" % way)


func test_the_cell_is_shut_until_its_door_is_opened() -> void:
	await _built()
	var prisoner := mission.prisoners()[0]
	var door := mission.get_node("CellDoor") as CellDoor
	assert_false(_reaches(door.stand_point(), prisoner.global_position))
	door.set_open(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(2)
	assert_true(_reaches(door.stand_point(), prisoner.global_position))


func test_the_sea_is_still_where_it_was() -> void:
	await _built()
	var sea := mission.get_node("Scenery/Sea") as Node3D
	assert_almost_eq(sea.position, Vector3(0, 0.35, 33 + 76), Vector3.ONE * 0.001)
