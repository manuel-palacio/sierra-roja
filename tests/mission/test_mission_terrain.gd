extends GutTest
## A mission whose ground is a Terrain: the navmesh, units and blockers all follow it.
## The land: flat at y = 0 for x < -15, a 20 degree slope from x = -15 to x = 15 along z < 0, a
## 45 degree face from x = 0 to x = 10 along z > 12 (far from the slope), flat elsewhere.

const SLOPE_RISE := 10.919  # 30 m at 20 degrees

var mission: Mission
var terrain: Terrain


func _ramp(from: Vector2, to: Vector2, half_width: float, rise: float) -> TerrainFeature:
	var f := TerrainFeature.new()
	f.kind = TerrainFeature.Kind.PATH
	f.mode = TerrainFeature.Mode.SET
	f.points = PackedVector2Array([from, to])
	f.width = half_width
	f.falloff = 0.0
	f.height = 0.0
	f.end_height = rise
	return f


func _nav_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 35.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.detail_sample_distance = 3.0
	nm.detail_sample_max_error = 0.15
	return nm


func before_each() -> void:
	mission = Mission.new()
	mission.bounds_rect = Rect2(-30, -20, 60, 40)
	var region := NavigationRegion3D.new()
	region.name = "Nav"
	region.navigation_mesh = _nav_mesh()
	mission.add_child(region)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.spec = TerrainSpec.new()
	terrain.spec.bounds = mission.bounds_rect
	terrain.spec.skirt = 8.0
	terrain.spec.features = [
		_ramp(Vector2(-15, -10), Vector2(15, -10), 6.0, SLOPE_RISE),
		_ramp(Vector2(0, 16), Vector2(10, 16), 3.0, 10.0),
	]
	region.add_child(terrain)


func _built() -> void:
	add_child_autofree(mission)
	await wait_physics_frames(2)
	mission.build_nav()


func _walker(at: Vector3) -> Specialist:
	var unit: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	mission.add_child(unit)
	unit.global_position = at
	unit.set_nav_map(mission.nav_map())
	return unit


func _nav_point(x: float, z: float) -> Vector3:
	return NavigationServer3D.map_get_closest_point(mission.nav_map(),
			Vector3(x, mission.ground_height(x, z), z))


func test_mission_finds_its_terrain_and_ground_height() -> void:
	await _built()
	assert_eq(mission.terrain(), terrain)
	assert_almost_eq(mission.ground_height(-20, 0), 0.0, 0.001)
	assert_almost_eq(mission.ground_height(0, -10), SLOPE_RISE / 2.0, 0.01)


func test_ground_height_is_zero_without_terrain() -> void:
	var bare := Mission.new()
	add_child_autofree(bare)
	assert_null(bare.terrain())
	assert_eq(bare.ground_height(3, 4), 0.0)


func test_navmesh_lies_on_the_ground() -> void:
	await _built()
	for p in [Vector2(-22, 0), Vector2(-5, -10), Vector2(8, -9), Vector2(22, 5)]:
		var on_nav := _nav_point(p.x, p.y)
		assert_almost_eq(Vector2(on_nav.x, on_nav.z), p, Vector2.ONE * 0.3, "navmesh reaches %s" % p)
		assert_almost_eq(on_nav.y, mission.ground_height(on_nav.x, on_nav.z), 0.2, "height at %s" % p)


func test_a_unit_walks_up_a_slope_on_the_ground() -> void:
	await _built()
	var unit := _walker(Vector3(-10, mission.ground_height(-10, -10), -10))
	var target := Vector3(0, mission.ground_height(0, -10), -10)
	unit.move_to(target)
	var worst := 0.0
	var arrived := [false]
	unit.arrived.connect(func(_u: Unit) -> void: arrived[0] = true)
	for i in 360:
		await get_tree().physics_frame
		if i > 20:
			var p := unit.global_position
			worst = maxf(worst, absf(p.y - mission.ground_height(p.x, p.z)))
		if arrived[0]:
			break
	assert_true(arrived[0], "arrives within 6 s")
	assert_lt(worst, 0.25, "never more than 0.25 m off the ground")
	assert_almost_eq(unit.global_position.x, 0.0, 0.5)
	assert_almost_eq(unit.ground_y(), unit.global_position.y, 0.05)


func test_a_standing_unit_settles_onto_the_ground() -> void:
	await _built()
	var unit := _walker(Vector3(5, 0, -10))  # the ground here is well above 0
	await wait_physics_frames(60)
	assert_almost_eq(unit.global_position.y, mission.ground_height(5, -10), 0.2)


func test_a_45_degree_face_has_no_navmesh() -> void:
	await _built()
	var on_nav := _nav_point(5, 16)
	assert_gt(Vector2(on_nav.x - 5, on_nav.z - 16).length(), 2.0)


func test_an_order_onto_ground_nobody_can_stand_on_ends_at_the_nearest_reachable_point() -> void:
	await _built()
	var unit := _walker(Vector3(-6, 0, 16))
	unit.move_to(Vector3(5, 5, 16))  # the middle of the 45 degree face
	await wait_physics_frames(300)
	assert_eq(unit.velocity, Vector3.ZERO, "stopped, not pushing at the face")
	var still := unit.global_position
	await wait_physics_frames(30)
	assert_eq(unit.global_position, still, "and not jittering")
	assert_gt(still.distance_to(Vector3(-6, 0, 16)), 2.0, "having walked toward it")
	assert_lt(terrain.field.slope_deg_at(still.x, still.z), 35.0, "on ground it can stand on")
	assert_almost_eq(unit.global_position.y, mission.ground_height(still.x, still.z), 0.2)


func test_a_box_blocker_leaves_a_hole_in_the_navmesh() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 8)
	shape.shape = box
	body.add_child(shape)
	mission.get_node("Nav").add_child(body)
	body.position = Vector3(-22, 1.5, 0)
	await _built()
	var inside := _nav_point(-22, 0)
	assert_gt(Vector2(inside.x + 22, inside.z).length(), 1.0, "no navmesh under the box")
	var path := NavigationServer3D.map_get_path(mission.nav_map(), Vector3(-26, 0, 0), Vector3(-18, 0, 0), true)
	assert_gt(path.size(), 2, "the path goes round")
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	assert_gt(length, 12.0)
