extends GutTest
## Scattered props on a small mission with a road, a patrol route and a house.

const PINE := preload("res://assets/props/nature/rock_tallA.glb")
const AREA: Array[Vector2] = [Vector2(-18, -12), Vector2(18, -12), Vector2(18, 12), Vector2(-18, 12)]

var mission: Mission
var region: NavigationRegion3D
var terrain: Terrain
var house: Building


func before_each() -> void:
	mission = Mission.new()
	mission.bounds_rect = Rect2(-20, -15, 40, 30)
	region = NavigationRegion3D.new()
	region.name = "Nav"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_slope = 35.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	region.navigation_mesh = nm
	mission.add_child(region)
	terrain = Terrain.new()
	terrain.spec = TerrainSpec.new()
	terrain.spec.bounds = mission.bounds_rect
	terrain.spec.skirt = 4.0
	var road := TerrainFeature.new()
	road.kind = TerrainFeature.Kind.PATH
	road.mode = TerrainFeature.Mode.SET
	road.points = PackedVector2Array([Vector2(-30, 6), Vector2(30, 6)])
	road.width = 1.5
	road.falloff = 1.0
	road.surface = HeightField.Surface.ROAD
	var face := TerrainFeature.new()  # a 45 degree face across the north of the area
	face.kind = TerrainFeature.Kind.PATH
	face.mode = TerrainFeature.Mode.SET
	face.points = PackedVector2Array([Vector2(0, -6), Vector2(0, -11)])
	face.width = 30.0
	face.falloff = 0.0
	face.height = 0.0
	face.end_height = 5.0
	terrain.spec.features = [road, face]
	region.add_child(terrain)
	house = Building.new()
	house.size = Vector3(4, 3, 4)
	region.add_child(house)
	house.position = Vector3(-10, 0, -2)
	var routes := Node3D.new()
	routes.name = "Routes"
	mission.add_child(routes)
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(5, 0, 0))
	path.curve.add_point(Vector3(12, 0, 0))
	routes.add_child(path)


func _scatter(blocking := false, p_seed := 3) -> PropScatter:
	var s := PropScatter.new()
	s.models = [PINE]
	s.area = PackedVector2Array(AREA)
	s.count = 40
	s.seed = p_seed
	s.min_spacing = 2.0
	s.keep_clear = 2.0
	if blocking:
		s.blocker_size = Vector3(0.5, 3.0, 0.5)
	region.add_child(s)
	return s


func _built() -> void:
	add_child_autofree(mission)
	await wait_physics_frames(2)
	mission.build_nav()
	await wait_physics_frames(2)


func _positions(s: PropScatter) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t in s.transforms():
		out.append(t.origin)
	return out


func test_same_seed_same_places_another_seed_other_places() -> void:
	var a := _scatter(false, 3)
	var b := _scatter(false, 3)
	var c := _scatter(false, 4)
	await _built()
	assert_gt(a.transforms().size(), 15, "most of the 40 found room")
	assert_eq(_positions(a), _positions(b))
	assert_ne(_positions(a), _positions(c))


func test_instances_keep_to_the_rules() -> void:
	var s := _scatter()
	await _built()
	var placed := _positions(s)
	for i in placed.size():
		var p := placed[i]
		assert_true(Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), s.area), "inside the area")
		assert_almost_eq(p.y, terrain.height_at(p.x, p.z), 0.01, "on the ground")
		assert_lt(terrain.field.slope_deg_at(p.x, p.z), s.max_slope_deg, "not on the steep face")
		assert_gt(absf(p.z - 6.0), 1.5 + s.keep_clear - 0.8, "clear of the road")
		assert_gt(Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(5, 0), Vector2(12, 0))
				.distance_to(Vector2(p.x, p.z)), s.keep_clear - 0.01, "clear of the patrol route")
		assert_false(absf(p.x + 10.0) < 2.0 + s.keep_clear and absf(p.z + 2.0) < 2.0 + s.keep_clear
				and Vector2(maxf(absf(p.x + 10.0) - 2.0, 0.0), maxf(absf(p.z + 2.0) - 2.0, 0.0)).length() < s.keep_clear,
				"clear of the house")
		for j in i:
			assert_gte(Vector2(p.x - placed[j].x, p.z - placed[j].z).length(), s.min_spacing - 0.001)


func test_models_become_multimeshes_with_one_instance_per_place() -> void:
	var s := _scatter()
	await _built()
	var total := 0
	var holders := s.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(holders.size(), 0)
	for node in holders:
		total += (node as MultiMeshInstance3D).multimesh.instance_count
	assert_eq(total, s.transforms().size())
	assert_eq(s.find_children("*", "CollisionShape3D", true, false).size(), 0, "decoration has no collision")


func test_extra_clear_points_are_kept_open() -> void:
	var s := _scatter()
	s.clear_points = PackedVector2Array([Vector2(14, -3)])
	s.keep_clear = 5.0
	await _built()
	assert_gt(s.transforms().size(), 5)
	for p in _positions(s):
		assert_gte(Vector2(p.x - 14.0, p.z + 3.0).length(), 5.0)


func test_scale_stays_in_range() -> void:
	var s := _scatter()
	s.scale_range = Vector2(3.0, 4.0)
	await _built()
	for t in s.transforms():
		assert_between(t.basis.get_scale().y, 3.0, 4.0)


func test_blocking_props_stop_feet_and_eyes() -> void:
	var s := _scatter(true)
	await _built()
	var placed := _positions(s)
	assert_eq(s.find_children("*", "CollisionShape3D", true, false).size(), placed.size())
	var p := placed[0]
	var on_nav := NavigationServer3D.map_get_closest_point(mission.nav_map(), p)
	assert_gt(Vector2(on_nav.x - p.x, on_nav.z - p.z).length(), 0.3, "no navmesh at the trunk")
	assert_false(Perception.line_clear(mission, p + Vector3(-0.6, 1, 0), p + Vector3(0.6, 1, 0)), "the trunk blocks sight")


func test_a_flat_colour_replaces_the_models_own_materials() -> void:
	var s := _scatter()
	s.flat_colour = Color(0.8, 0.66, 0.3)
	await _built()
	var holders := s.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(holders.size(), 0)
	for node in holders:
		var mesh := (node as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			assert_eq((mesh.surface_get_material(i) as BaseMaterial3D).albedo_color, Color(0.8, 0.66, 0.3, 1.0))


func test_a_scatter_of_generated_trees_needs_no_models() -> void:
	var s := _scatter(true)
	s.models = []
	s.tree_kind = &"oak"
	await _built()
	assert_gt(s.transforms().size(), 10)
	var total := 0
	var meshes := {}
	for node in s.find_children("*", "MultiMeshInstance3D", true, false):
		var multi := (node as MultiMeshInstance3D).multimesh
		total += multi.instance_count
		meshes[multi.mesh] = true
		assert_true(multi.mesh in TreeBuilder.variants(&"oak"))
	assert_eq(total, s.transforms().size(), "one tree per place")
	assert_gt(meshes.size(), 1, "more than one variant in use")
	assert_eq(s.find_children("*", "CollisionShape3D", true, false).size(), total, "each with its trunk to walk round")


# --- Winter ---

func test_snowy_scatter_places_exactly_what_a_plain_one_does() -> void:
	var plain := _scatter(true, 9)
	var snowy := _scatter(true, 9)
	snowy.snowy = true
	await _built()
	assert_gt(plain.transforms().size(), 0)
	assert_eq(snowy.transforms(), plain.transforms())


func test_snowy_rocks_are_paler() -> void:
	var plain := _scatter(false, 9)
	var snowy := _scatter(false, 9)
	snowy.snowy = true
	await _built()
	var material := func(s: PropScatter) -> BaseMaterial3D:
		var holder := s.find_children("*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
		return holder.multimesh.mesh.surface_get_material(0) as BaseMaterial3D
	var rock: BaseMaterial3D = material.call(plain)
	var frosted: BaseMaterial3D = material.call(snowy)
	assert_not_null(rock.albedo_texture, "a plain rock wears the rock texture, which is dark")
	assert_null(frosted.albedo_texture, "a snowy one wears its colour flat")
	assert_gt(frosted.albedo_color.get_luminance(), 0.7, "and that colour is most of the way to snow")
