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


# --- Soft shade where things stand ---

func test_things_on_the_land_sit_in_a_pool_of_shade() -> void:
	var wall := StoneWall.new()
	wall.points = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)])
	region.add_child(wall)
	var house := Building.new()
	house.size = Vector3(5, 3, 4)
	region.add_child(house)
	house.position = Vector3(10, 0, -8)
	await _built()
	var land := mission.terrain()
	assert_eq(land.shade_at(-15, 10), 1.0, "open ground is unshaded")
	assert_lt(land.shade_at(0, 0.6), 0.7, "dark right beside the wall")
	assert_between(land.shade_at(0, 1.1), 0.55, 0.99, "easing off a little way out")
	assert_eq(land.shade_at(0, 4.0), 1.0, "and gone a few metres away")
	assert_lt(land.shade_at(12.9, -8), 0.75, "the house too")
	assert_gt(land.shade_at(0, 0.6), 0.1, "shade, not a black hole")


func test_trees_shade_the_ground_under_their_crowns() -> void:
	var trees := PropScatter.new()
	trees.tree_kind = &"oak"
	trees.area = PackedVector2Array([Vector2(-18, -12), Vector2(18, -12), Vector2(18, 12), Vector2(-18, 12)])
	trees.count = 6
	trees.min_spacing = 9.0
	region.add_child(trees)
	await _built()
	var land := mission.terrain()
	assert_gt(trees.transforms().size(), 2)
	for t in trees.transforms():
		assert_lt(land.shade_at(t.origin.x, t.origin.z), 0.8, "under a crown")


func test_a_sandbag_wall_blocks_like_any_wall() -> void:
	var bags := StoneWall.new()
	bags.kind = &"sandbags"
	bags.points = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0)])
	region.add_child(bags)
	await _built()
	assert_gt(bags.find_children("*", "CollisionShape3D", true, false).size(), 4, "in short bags, not long blocks")
	assert_gt(_off_navmesh(0, 0), 0.5)


func test_a_telegraph_pole_stands_on_the_ground_and_is_wired_to_the_next() -> void:
	var pole := TelegraphPole.new()
	pole.wire_to = Vector2(14, 5)
	mission.add_child(pole)
	pole.position = Vector3(0, 0, 5)
	var last := TelegraphPole.new()
	mission.add_child(last)
	last.position = Vector3(14, 0, 5)
	await _built()
	assert_almost_eq(pole.global_position.y, 2.0, 0.01, "set down on the land")
	var meshes := pole.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 6, "post, arm, two insulators, two wires")
	assert_eq(last.find_children("*", "MeshInstance3D", true, false).size(), 4, "the last of a line has no wires on")
	assert_eq(pole.find_children("*", "CollisionShape3D", true, false).size(), 0)
	var longest := 0.0
	for m in meshes:
		longest = maxf(longest, ((m as MeshInstance3D).mesh.get_aabb().size.z))
	assert_almost_eq(longest, 14.0, 0.2, "the wires reach the next pole")


func test_a_watchtower_and_a_cart_stand_on_the_ground_and_block() -> void:
	var tower := Watchtower.new()
	region.add_child(tower)
	tower.position = Vector3(-8, 0, 6)
	var cart := Cart.new()
	region.add_child(cart)
	cart.position = Vector3(8, 0, 6)
	await _built()
	for thing: StaticBody3D in [tower, cart]:
		assert_almost_eq(thing.global_position.y, 2.0, 0.01, "set down on the land")
		assert_eq(thing.collision_layer, Unit.LAYER_WORLD)
		assert_gt(thing.find_children("*", "MeshInstance3D", true, false).size(), 6, "built of many pieces")
		assert_gt(_off_navmesh(thing.global_position.x, thing.global_position.z), 0.8, "nobody walks through it")
		assert_lt(mission.terrain().shade_at(thing.global_position.x + 1.6, thing.global_position.z), 0.95, "and it sits in shade")
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(8, 2, 9.5))
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(8, 2, 3.0)) as Specialist
	await wait_physics_frames(2)
	assert_ne(_sees(guard, spec), Vision.Zone.NONE, "someone standing shows over the cart")
	spec.set_stance(Unit.Stance.CRAWLING)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "lying behind it they are hidden")


# --- Going inside ---

func _house(at: Vector3) -> Building:
	var house := Building.new()
	house.size = Vector3(7, 3, 5)
	house.enterable = true
	region.add_child(house)
	house.position = at
	return house


func test_a_house_can_be_walked_into_by_its_door_and_only_by_its_door() -> void:
	var house := _house(Vector3.ZERO)
	await _built()
	assert_lt(_off_navmesh(0, 0), 0.05, "the floor inside is walkable")
	var inside := Vector3(0, 2, 0)
	var from_south := NavigationServer3D.map_get_path(mission.nav_map(), Vector3(0, 2, 9), inside, true)
	assert_lt(from_south[-1].distance_to(inside), 0.6, "in by the door on the south side")
	var from_north := NavigationServer3D.map_get_path(mission.nav_map(), Vector3(0, 2, -9), inside, true)
	var length := 0.0
	for i in from_north.size() - 1:
		length += from_north[i].distance_to(from_north[i + 1])
	assert_gt(length, 16.0, "from behind, the way in is round to the front")
	assert_gt(_off_navmesh(-3.3, 0), 0.3, "the walls still block")
	assert_true(house.holds(inside))
	assert_false(house.holds(Vector3(0, 2, 6)))


func test_walls_hide_whoever_is_inside_and_the_doorway_does_not() -> void:
	_house(Vector3.ZERO)
	await _built()
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, 0)) as Specialist
	var from_the_side := _unit("res://scenes/units/guard.tscn", Vector3(-9, 2, 0))
	from_the_side.rotation.y = -PI / 2.0  # facing east, at the west wall
	var through_the_door := _unit("res://scenes/units/guard.tscn", Vector3(0, 2, 8))
	await wait_physics_frames(2)
	assert_eq(_sees(from_the_side, spec), Vision.Zone.NONE, "a wall is in the way")
	assert_ne(_sees(through_the_door, spec), Vision.Zone.NONE, "seen through the open doorway")


func test_the_roof_comes_off_the_picture_while_a_specialist_is_inside() -> void:
	var house := _house(Vector3.ZERO)
	await _built()
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, 9)) as Specialist
	house.look_inside()
	assert_false(house.is_open(), "roof on with nobody in")
	assert_true((house.get_node("Roof") as Node3D).visible)
	spec.global_position = Vector3(1, 2, 0.5)
	house.look_inside()
	assert_true(house.is_open())
	assert_false((house.get_node("Roof") as Node3D).visible)
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(-1, 2, 0))
	spec.global_position = Vector3(0, 2, 9)
	house.look_inside()
	assert_false(house.is_open(), "a guard inside does not open it: only what the squad sees from inside")
	assert_not_null(guard)
	spec.global_position = Vector3(1, 2, 0.5)
	spec.take_damage(1000)
	house.look_inside()
	assert_false(house.is_open(), "nor does a dead specialist")


func test_a_lamp_lights_the_room_only_while_it_is_looked_into() -> void:
	var house := _house(Vector3.ZERO)
	await _built()
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, 9)) as Specialist
	var lamp := house.get_node("RoomLamp") as OmniLight3D
	house.look_inside()
	assert_false(lamp.visible, "dark under its roof, so no light leaks through the walls")
	spec.global_position = Vector3(1, 2, 0.5)
	house.look_inside()
	assert_true(lamp.visible)
	assert_true(house.holds(house.to_global(lamp.position)), "the lamp hangs inside the walls")


func test_the_walls_towards_the_camera_are_cut_low_while_the_room_is_looked_into() -> void:
	var house := _house(Vector3.ZERO)
	await _built()
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.look_at_from_position(Vector3(20, 20, 20), Vector3.ZERO)  # from the south-east
	camera.current = true
	var spec := _unit("res://scenes/units/specialist.tscn", Vector3(0, 2, 9)) as Specialist
	house.look_inside()
	for side in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]:
		assert_false(house.is_wall_cut(side), "whole with nobody in: %s" % side)
	spec.global_position = Vector3(1, 2, 0.5)
	house.look_inside()
	assert_true(house.is_wall_cut(Vector3.BACK), "the south wall, towards the camera")
	assert_true(house.is_wall_cut(Vector3.RIGHT), "the east wall, towards the camera")
	assert_false(house.is_wall_cut(Vector3.FORWARD), "the north wall stands behind the room")
	assert_false(house.is_wall_cut(Vector3.LEFT))
	camera.look_at_from_position(Vector3(-20, 20, -20), Vector3.ZERO)  # the camera turned half round
	house.look_inside()
	assert_false(house.is_wall_cut(Vector3.BACK))
	assert_true(house.is_wall_cut(Vector3.FORWARD))
	assert_true(house.is_wall_cut(Vector3.LEFT))
	var guard := _unit("res://scenes/units/guard.tscn", Vector3(-9, 2, 0))
	guard.rotation.y = -PI / 2.0
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "a wall cut low on the picture still hides whoever is inside")


func test_a_house_not_made_enterable_is_as_solid_as_before() -> void:
	var house := Building.new()
	house.size = Vector3(7, 3, 5)
	house.storeys = 2
	region.add_child(house)
	await _built()
	assert_gt(_off_navmesh(0, 0), 2.0)
	house.look_inside()
	assert_false(house.is_open())


# --- Lived-in places ---

func test_settlement_props_stand_on_the_ground_and_the_solid_ones_block() -> void:
	var made := {}
	var x := -14.0
	for kind in SettlementProp.KINDS:
		var prop := SettlementProp.new()
		prop.kind = kind
		region.add_child(prop)
		prop.position = Vector3(x, 0, 6)
		made[kind] = prop
		x += 8.0
	await _built()
	for kind in made:
		var prop: SettlementProp = made[kind]
		assert_almost_eq(prop.global_position.y, 2.0, 0.01, "%s set down on the land" % kind)
		assert_gt(prop.find_children("*", "MeshInstance3D", true, false).size(), 1, "%s is built of pieces" % kind)
		var solid: Vector3 = SettlementProp.KINDS[kind]
		var off := _off_navmesh(prop.global_position.x, prop.global_position.z)
		if solid == Vector3.ZERO:
			assert_lt(off, 0.05, "%s is walked under" % kind)
			assert_eq(prop.find_children("*", "CollisionShape3D", true, false).size(), 0)
		else:
			assert_gt(off, 0.5, "%s is walked round" % kind)
	var truck: SettlementProp = made[&"truck"]
	var guard := _unit("res://scenes/units/guard.tscn", truck.global_position + Vector3(4, 0, 0))
	guard.rotation.y = PI / 2.0  # facing west, at the truck's side
	var spec := _unit("res://scenes/units/specialist.tscn", truck.global_position + Vector3(-3, 0, 0)) as Specialist
	await wait_physics_frames(2)
	assert_eq(_sees(guard, spec), Vision.Zone.NONE, "a truck hides someone standing behind it")
