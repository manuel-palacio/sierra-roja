extends GutTest
## Builds small broken missions in code and checks the validator names the problem.


func _nav_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	return nm


func _marker(parent: Node, node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	parent.add_child(m)
	m.position = pos
	return m


func _container(mission: Mission, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	mission.add_child(n)
	return n


func _floor(region: NavigationRegion3D, from_x: float, to_x: float) -> void:
	var box := CSGBox3D.new()
	box.size = Vector3(to_x - from_x, 1.0, 10.0)
	region.add_child(box)
	box.position = Vector3((from_x + to_x) * 0.5, -0.5, 0.0)


## A mission with floors [-10,-2] and [2,10] (or one floor [-10,10] when joined),
## full spawns, one route, bridge target and extraction on the right-hand side.
func _small_mission(joined: bool) -> Mission:
	var mission := Mission.new()
	var region := NavigationRegion3D.new()
	region.name = "Nav"
	region.navigation_mesh = _nav_mesh()
	mission.add_child(region)
	if joined:
		_floor(region, -10.0, 10.0)
	else:
		_floor(region, -10.0, -2.0)
		_floor(region, 2.0, 10.0)
	var sp := _container(mission, "SpecialistSpawns")
	_marker(sp, "S1", Vector3(-8, 0, 0))
	_marker(sp, "S2", Vector3(-8, 0, 2))
	var gs := _container(mission, "GuardSpawns")
	for i in 3:
		_marker(gs, "G%d" % i, Vector3(6, 0, i))
	var routes := _container(mission, "Routes")
	for i in 3:
		var path := Path3D.new()
		path.curve = Curve3D.new()
		path.curve.add_point(Vector3(6, 0, i))
		path.curve.add_point(Vector3(8, 0, i))
		path.name = "Route%d" % i
		routes.add_child(path)
	_marker(mission, "BridgeTarget", Vector3(6, 0, 0))
	var ex := Area3D.new()
	ex.name = "Extraction"
	mission.add_child(ex)
	ex.position = Vector3(8, 0, 3)
	return mission


func _built(mission: Mission) -> Mission:
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().process_frame
	mission.build_nav()
	return mission


func _joined_text(errors: PackedStringArray) -> String:
	return "\n".join(errors)


func test_missing_spawn_reported() -> void:
	var mission := Mission.new()
	add_child_autofree(mission)
	var errors := MissionValidator.validate(mission)
	var text := _joined_text(errors)
	assert_string_contains(text, "needs 2 specialist spawns")
	assert_string_contains(text, "needs 3 guard spawns")


func test_empty_route_reported() -> void:
	var mission: Mission = _small_mission(true)
	var routes := mission.get_node("Routes")
	routes.get_child(1).curve = Curve3D.new()
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "route Route1 needs at least 2 points")


func test_unreachable_objective_reported() -> void:
	var mission: Mission = _small_mission(false)
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "bridge target is unreachable")
	assert_string_contains(text, "extraction is unreachable")


func test_small_valid_mission_passes() -> void:
	var mission: Mission = _small_mission(true)
	await _built(mission)
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_guard_spawn_off_the_ground_is_named() -> void:
	var mission: Mission = _small_mission(true)
	mission.get_node("GuardSpawns/G1").position = Vector3(40, 0, 0)
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "guard spawn G1 is not on walkable ground")


func test_route_point_off_the_ground_is_named() -> void:
	var mission: Mission = _small_mission(true)
	(mission.get_node("Routes/Route2") as Path3D).curve.add_point(Vector3(0, 0, 30))
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "route Route2 point 2 is not on walkable ground")


func test_specialist_spawn_off_the_ground_is_named() -> void:
	var mission: Mission = _small_mission(true)
	mission.get_node("SpecialistSpawns/S2").position = Vector3(-8, 0, 30)
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "specialist spawn S2 is not on walkable ground")


func test_route_that_cannot_be_walked_is_named() -> void:
	# Both ends stand on walkable ground, but on floors with a gap between them.
	var mission: Mission = _small_mission(false)
	var route := mission.get_node("Routes/Route1") as Path3D
	route.curve = Curve3D.new()
	route.curve.add_point(Vector3(-6, 0, 1))
	route.curve.add_point(Vector3(6, 0, 1))
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "route Route1 leg 0 cannot be walked")
	assert_false(text.contains("Route0"), "the routes that can be walked are not named")


func test_closing_leg_of_a_loop_is_checked_too() -> void:
	var mission: Mission = _small_mission(false)
	var route := mission.get_node("Routes/Route2") as Path3D
	route.curve = Curve3D.new()
	for p in [Vector3(4, 0, 0), Vector3(8, 0, 0), Vector3(-6, 0, 2)]:
		route.curve.add_point(p)
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "route Route2 leg 1 cannot be walked")
	assert_string_contains(text, "route Route2 leg 2 cannot be walked", "back to the start")


func test_marker_hanging_in_the_air_is_named() -> void:
	var mission: Mission = _small_mission(true)
	mission.get_node("GuardSpawns/G2").position = Vector3(6, 4, 2)
	mission.get_node("SpecialistSpawns/S1").position = Vector3(-8, -3, 0)
	await _built(mission)
	var text := _joined_text(MissionValidator.validate(mission))
	assert_string_contains(text, "guard spawn G2 is 4.0 m off the ground")
	assert_string_contains(text, "specialist spawn S1 is 3.0 m off the ground")
