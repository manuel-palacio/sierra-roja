extends GutTest
## The second mission's map: a walled farm used as an ammunition store.

const SCENE := "res://scenes/missions/powder_store.tscn"

var mission: Mission


func _built(guards_active := false) -> void:
	mission = load(SCENE).instantiate()
	if not guards_active:
		mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().physics_frame
	mission.build_nav()
	await wait_physics_frames(2)


func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.y), p.y)


func _path_length(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(mission.nav_map(), from, to, true)
	if path.is_empty() or Vector2(path[-1].x - to.x, path[-1].z - to.z).length() > 1.0:
		return INF
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length


func test_it_is_valid_and_says_what_it_is() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())
	assert_eq(mission.title, "The depot outside Teruel")
	assert_eq(mission.objectives()[0].marker_name, "Depot")
	assert_eq(mission.objectives()[0].hud_text, "Destroy the depot")
	assert_eq(mission.briefing_lines.size(), 3)
	assert_eq(mission.guards().size(), 6)
	assert_eq(mission.specialist_spawns().size(), 2)
	assert_null(mission.get_node_or_null("Nav/BridgeDeck"), "no bridge here")
	assert_not_null(mission.get_node_or_null("Nav/TargetStack"))


func test_navmesh_stays_small_enough_for_the_path_search() -> void:
	await _built()
	var polygons := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh.get_polygon_count()
	assert_between(polygons, 300, 2000)


func test_there_are_three_ways_into_the_yard() -> void:
	await _built()
	var start := mission.specialist_spawns()[0].global_position
	var yard := _on_ground(Vector2(6, 6))
	var direct := start.distance_to(yard)
	# By the south gate, by the east gate and by the gap in the west wall: each is a walkable
	# way in that does not lead far round.
	for way in [Vector2(5, 14), Vector2(22, 0), Vector2(-12, -7.5)]:
		var outside := _on_ground(way)
		assert_lt(_path_length(start, outside), 120.0, "from the start to outside %s" % way)
		assert_lt(_path_length(outside, yard), outside.distance_to(yard) * 1.6 + 6.0, "in through %s" % way)
	assert_lt(_path_length(start, yard), direct * 1.5)
	assert_lt(_path_length(yard, mission.extraction().global_position), 80.0, "and out to the camp")


func test_the_farm_wall_hides_a_standing_figure() -> void:
	await _built()
	var guard: Guard = mission.guards()[2]  # the east wall's
	var spec: Specialist = mission.spawn_specialists()[0]
	guard.global_position = _on_ground(Vector2(23.5, 6))
	guard.rotation.y = PI / 2.0  # facing west, at the wall
	spec.global_position = _on_ground(Vector2(16, 6))
	await wait_physics_frames(2)
	assert_eq(Perception.sees(guard, spec, Vision.defaults().target_height(spec.stance)), Vision.Zone.NONE)
	spec.global_position = _on_ground(Vector2(16, 0))
	guard.global_position = _on_ground(Vector2(23.5, 0))
	await wait_physics_frames(2)
	assert_ne(Perception.sees(guard, spec, Vision.defaults().target_height(spec.stance)), Vision.Zone.NONE,
			"but through the gate it is seen")


func test_every_patrol_leg_is_walkable_without_a_detour() -> void:
	await _built()
	for guard in mission.guards():
		var route := mission.guard_route(String(guard.name))
		for i in route.size():
			var from := route[i]
			var to := route[(i + 1) % route.size()]
			assert_lt(_path_length(from, to), from.distance_to(to) * 1.15 + 0.5, "%s leg %d" % [guard.name, i])


func test_a_charge_by_the_stack_destroys_it_and_the_mission_can_then_be_won() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specialists)
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	mission.add_child(charge)
	charge.global_position = _on_ground(Vector2(3.5, 2.5))  # at the stack's corner, inside 8 m
	charge.advance(0.1)
	await wait_physics_frames(4)
	assert_true(rules.objectives_done(), "the target is destroyed")
	assert_null(mission.get_node_or_null("Nav/TargetStack"), "the stack is gone")
	assert_not_null(mission.get_node_or_null("TargetWreck"), "a scorched patch is left")
	assert_eq(rules.result, MissionRules.Result.RUNNING, "nobody is cut off: there is no bridge to lose")
	assert_lt(Vector2(NavigationServer3D.map_get_closest_point(mission.nav_map(), _on_ground(Vector2(6, -1))).x - 6.0, 0).length(),
			0.5, "and where it stood can be walked over")
	for s in specialists:
		s.global_position = mission.extraction().global_position + Vector3(0, -1.5, 0)
	await wait_physics_frames(4)
	assert_eq(rules.result, MissionRules.Result.WON)
	mission.repair_bridge()
	await wait_physics_frames(3)
	assert_not_null(mission.get_node_or_null("Nav/TargetStack"), "a load from before the blast puts it back")
	assert_null(mission.get_node_or_null("TargetWreck"))


func test_a_charge_outside_the_wall_is_too_far() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specialists)
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	mission.add_child(charge)
	charge.global_position = _on_ground(Vector2(6, -14))
	charge.advance(0.1)
	await wait_physics_frames(2)
	assert_false(rules.objectives_done(), "the stack cannot be blown from outside the farm")


func test_it_is_winter_at_teruel() -> void:
	await _built()
	assert_eq(mission.season, &"snow")
	assert_eq(mission.light, &"overcast")
	assert_false(mission.night)
	assert_true(mission.snowfall)
	assert_eq(mission.dress, &"spain_winter")
	assert_eq(mission.terrain().season, &"snow")
	assert_eq(mission.briefing_lines.size(), 3)
