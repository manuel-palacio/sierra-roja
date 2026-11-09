extends GutTest
## Dry-stone walls and buildings on a small flat mission: what they hide and where nobody can walk.

var mission: Mission
var region: NavigationRegion3D


func before_each() -> void:
	mission = Mission.new()
	mission.bounds_rect = Rect2(-20, -15, 40, 30)
	region = NavigationRegion3D.new()
	region.name = "Nav"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	region.navigation_mesh = nm
	mission.add_child(region)
	var terrain := Terrain.new()
	terrain.spec = TerrainSpec.new()
	terrain.spec.bounds = mission.bounds_rect
	terrain.spec.skirt = 4.0
	terrain.spec.base_height = 2.0
	region.add_child(terrain)


func _built() -> void:
	add_child_autofree(mission)
	await wait_physics_frames(2)
	mission.build_nav()
	await wait_physics_frames(2)


func _unit(scene: String, at: Vector3) -> Unit:
	var unit: Unit = load(scene).instantiate()
	mission.add_child(unit)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.global_position = at
	return unit


func _off_navmesh(x: float, z: float) -> float:
	var p := NavigationServer3D.map_get_closest_point(mission.nav_map(), Vector3(x, 2.0, z))
	return Vector2(p.x - x, p.z - z).length()


func _sees(guard: Unit, spec: Specialist) -> Vision.Zone:
	return Perception.sees(guard, spec, Vision.defaults().target_height(spec.stance))


func test_a_stone_wall_hides_a_crawler_but_not_a_stander() -> void:
	var wall := StoneWall.new()
	wall.points = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)])
	region.add_child(wall)
	await _built()
	# The guard looks along -z across the wall at a specialist 3 m away.
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(0, 2, 1.5))
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, -1.5)) as Specialist
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NEAR, "the stander's head shows over the wall")
	spec.set_stance(Unit.Stance.CRAWLING)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "the wall hides the crawler")
	spec.global_position = Vector3(8, 2, -1.5)
	guard.global_position = Vector3(8, 2, 1.5)
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NEAR, "past the wall's end the crawler is seen")


func test_a_stone_wall_stands_on_the_ground_and_blocks_walking() -> void:
	var wall := StoneWall.new()
	wall.points = PackedVector2Array([Vector2(-6, 0), Vector2(0, 0), Vector2(0, 6)])
	region.add_child(wall)
	await _built()
	assert_eq(wall.collision_layer, Unit.LAYER_WORLD)
	var boxes := wall.find_children("*", "CollisionShape3D", true, false)
	assert_gt(boxes.size(), 1, "one box per stretch of wall")
	for node in boxes:
		var shape := node as CollisionShape3D
		assert_true(shape.shape is BoxShape3D)
		var top := shape.global_position.y + (shape.shape as BoxShape3D).size.y / 2.0
		assert_almost_eq(top, 2.0 + wall.wall_height, 0.15, "top about wall_height above the ground")
	assert_gt(wall.find_children("*", "MeshInstance3D", true, false).size(), 0)
	assert_gt(_off_navmesh(-3, 0), 0.5, "no navmesh under the wall")
	assert_gt(_off_navmesh(0, 3), 0.5, "nor under its second stretch")
	assert_lt(_off_navmesh(-3, 3), 0.05, "but beside it there is")


func test_a_building_blocks_sight_and_walking() -> void:
	var house := Building.new()
	house.size = Vector3(5, 3, 4)
	region.add_child(house)
	house.position = Vector3(0, 0, 0)
	await _built()
	assert_eq(house.collision_layer, Unit.LAYER_WORLD)
	assert_almost_eq(house.global_position.y, 2.0, 0.01, "set on the ground")
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(0, 2, 5))
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, -4)) as Specialist
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "a stander behind the house is hidden")
	assert_gt(_off_navmesh(0, 0), 2.0, "nobody walks through it")
	assert_gt(_off_navmesh(2.6, 0), 0.3, "nor hugs its wall closer than their own radius")
	assert_lt(_off_navmesh(4.5, 0), 0.05)
	assert_gt(house.find_children("*", "MeshInstance3D", true, false).size(), 1, "walls and a roof")


func test_a_ruin_has_no_roof_and_can_be_entered() -> void:
	var ruin := Building.new()
	ruin.size = Vector3(7, 2.6, 6)
	ruin.ruin = true
	region.add_child(ruin)
	await _built()
	assert_lt(_off_navmesh(0, 0), 0.05, "the floor inside is walkable")
	var path := NavigationServer3D.map_get_path(mission.nav_map(), Vector3(0, 2, 10), Vector3(0, 2, 0), true)
	assert_false(path.is_empty())
	if not path.is_empty():
		assert_lt(path[path.size() - 1].distance_to(Vector3(0, 2, 0)), 1.0, "and a path leads in")
	assert_gt(_off_navmesh(-3.3, 0), 0.3, "its walls still block")
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(-8, 2, 0))
	guard.rotation.y = -PI / 2.0  # facing +x, at the ruin's west wall
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, 0)) as Specialist
	spec.set_stance(Unit.Stance.CRAWLING)
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "a crawler inside is hidden by the wall")
