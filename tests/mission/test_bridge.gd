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
