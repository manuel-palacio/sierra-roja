extends GutTest


func _spec(with_mound: bool) -> TerrainSpec:
	var s := TerrainSpec.new()
	s.bounds = Rect2(-30, -20, 60, 40)
	s.skirt = 10.0
	s.seed = 4
	s.noise_amplitude = 0.6
	if with_mound:
		var mound := TerrainFeature.new()
		mound.points = PackedVector2Array([Vector2.ZERO])
		mound.width = 2.0
		mound.falloff = 6.0
		mound.height = 5.0
		s.features = [mound]
	return s


func _terrain(with_mound := false) -> Terrain:
	var t := Terrain.new()
	t.spec = _spec(with_mound)
	add_child_autofree(t)
	await wait_physics_frames(2)
	return t


func _ray_down(t: Terrain, x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 50, z), Vector3(x, -50, z), Unit.LAYER_WORLD)
	return t.get_world_3d().direct_space_state.intersect_ray(query)


func test_collision_is_the_field() -> void:
	var t := await _terrain(true)
	assert_eq(t.collision_layer, Unit.LAYER_WORLD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 10:
		var x := rng.randf_range(-30, 30)
		var z := rng.randf_range(-20, 20)
		var hit := _ray_down(t, x, z)
		assert_true(hit.has("position"), "ground under (%.1f, %.1f)" % [x, z])
		if hit.has("position"):
			assert_almost_eq(hit["position"].y, t.field.height_at(x, z), 0.01)
			assert_almost_eq(t.height_at(x, z), t.field.height_at(x, z), 0.0001)


func test_collision_stops_a_margin_past_the_bounds() -> void:
	var t := await _terrain()
	assert_true(_ray_down(t, 30 + Terrain.COLLISION_MARGIN - 1.5, 0).has("position"))
	assert_false(_ray_down(t, 30 + Terrain.COLLISION_MARGIN + 1.5, 0).has("position"))


func test_a_mound_blocks_sight_that_flat_ground_does_not() -> void:
	var t := await _terrain(true)
	var eye := func(x: float, z: float) -> Vector3: return Vector3(x, t.height_at(x, z) + 1.6, z)
	assert_false(Perception.line_clear(t, eye.call(-9, 0), eye.call(9, 0)), "across the mound")
	assert_true(Perception.line_clear(t, eye.call(-9, 14), eye.call(9, 14)), "beside it")


func test_faces_cover_the_asked_area_only() -> void:
	var t := await _terrain()
	var area := Rect2(-10, -5, 20, 10)
	var faces := t.faces(area)
	assert_eq(faces.size(), 20 * 10 * 2 * 3, "two triangles per 1 m quad")
	var grown := area.grow(t.field.cell + 0.001)
	var outside := 0
	for v in faces:
		if not grown.has_point(Vector2(v.x, v.z)):
			outside += 1
		elif absf(v.y - t.field.height_at(v.x, v.z)) > 0.0001:
			outside += 1
	assert_eq(outside, 0)


func test_mesh_is_split_into_chunks() -> void:
	var t := await _terrain()
	var quads_x := t.field.cols - 1   # 80
	var quads_z := t.field.rows - 1   # 60
	var expected := ceili(float(quads_x) / Terrain.CHUNK) * ceili(float(quads_z) / Terrain.CHUNK)
	var meshes := t.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), expected)
	var triangles := 0
	for m in meshes:
		triangles += (m as MeshInstance3D).mesh.get_faces().size() / 3
	if DisplayServer.get_name() != "headless":
		assert_eq(triangles, quads_x * quads_z * 2)


func test_build_twice_leaves_one_terrain() -> void:
	var t := await _terrain()
	var before := t.get_child_count()
	t.build()
	assert_eq(t.get_child_count(), before)
