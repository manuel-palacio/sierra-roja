extends GutTest


func test_bridge_valid() -> void:
	var mission: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().process_frame
	mission.build_nav()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_bridge_counts() -> void:
	var mission: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	assert_eq(mission.specialist_spawns().size(), 2)
	assert_eq(mission.guard_spawns().size(), 3)
	assert_eq(mission.patrol_routes().size(), 3)
	assert_not_null(mission.bridge_target())
	assert_not_null(mission.extraction())


func test_extraction_is_far_side_from_start() -> void:
	var mission: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	var start := mission.specialist_spawns()[0].global_position
	var bridge := mission.bridge_target().global_position
	var out := mission.extraction().global_position
	assert_gt(out.distance_to(start), 60.0)
	# start and extraction lie on opposite sides of the gorge, the bridge between them
	assert_lt(start.x, bridge.x)
	assert_gt(out.x, bridge.x)


func test_bridge_has_three_guards_at_their_spawns() -> void:
	var mission: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	var guards := mission.guards()
	assert_eq(guards.size(), 3)
	var spawns := mission.guard_spawns()
	for i in guards.size():
		assert_almost_eq(guards[i].global_position, spawns[i].global_position, Vector3.ONE * 0.001)
		assert_eq(guards[i].route_size(), mission.patrol_routes()[i].curve.point_count)


func test_guards_walk_their_routes_once_nav_is_built() -> void:
	var mission: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().process_frame
	var starts: Array[Vector3] = []
	for guard in mission.guards():
		starts.append(guard.global_position)
	mission.build_nav()
	await wait_seconds(0.5)
	for i in starts.size():
		var walked := mission.guards()[i].global_position.distance_to(starts[i])
		assert_almost_eq(walked, 1.5, 0.5, "walks at 3 m/s")
		assert_eq(mission.guards()[i].brain.state, GuardBrain.State.PATROL)
