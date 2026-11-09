extends GutTest


func _spec(features: Array[TerrainFeature] = [], noise := 0.0, p_seed := 1) -> TerrainSpec:
	var s := TerrainSpec.new()
	s.bounds = Rect2(-20, -10, 40, 20)
	s.skirt = 5.0
	s.base_height = 1.0
	s.seed = p_seed
	s.noise_amplitude = noise
	s.features = features
	return s


func _feature(kind: TerrainFeature.Kind, mode: TerrainFeature.Mode, points: Array, width: float,
		falloff: float, height: float) -> TerrainFeature:
	var f := TerrainFeature.new()
	f.kind = kind
	f.mode = mode
	f.points = PackedVector2Array(points)
	f.width = width
	f.falloff = falloff
	f.height = height
	return f


func _heights(field: HeightField) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for r in field.rows:
		for c in field.cols:
			out.append(field.get_h(c, r))
	return out


func test_field_covers_the_bounds_and_the_skirt() -> void:
	var field := TerrainGenerator.build(_spec())
	assert_eq(field.rect(), Rect2(-25, -15, 50, 30))
	assert_almost_eq(field.height_at(0, 0), 1.0, 0.0001, "base height with no noise")


func test_same_spec_gives_the_same_land_and_another_seed_does_not() -> void:
	var a := _heights(TerrainGenerator.build(_spec([], 1.5, 7)))
	var b := _heights(TerrainGenerator.build(_spec([], 1.5, 7)))
	var c := _heights(TerrainGenerator.build(_spec([], 1.5, 8)))
	assert_eq(a, b)
	assert_ne(a, c)


func test_noise_stays_inside_its_amplitude() -> void:
	var field := TerrainGenerator.build(_spec([], 1.5, 3))
	var lo := INF
	var hi := -INF
	for h in _heights(field):
		lo = minf(lo, h)
		hi = maxf(hi, h)
	assert_gte(lo, 1.0 - 1.5)
	assert_lte(hi, 1.0 + 1.5)
	assert_gt(hi - lo, 0.5, "and it is not flat")


func test_set_path_is_exact_inside_its_width_despite_noise() -> void:
	var path := _feature(TerrainFeature.Kind.PATH, TerrainFeature.Mode.SET,
			[Vector2(-15, 0), Vector2(15, 0)], 2.0, 3.0, 4.0)
	var field := TerrainGenerator.build(_spec([path], 1.5, 3))
	for x in range(-15, 16):
		for z in range(-2, 3):
			assert_almost_eq(field.height_at(x, z), 4.0, 0.0001)
	assert_ne(field.height_at(0, 4), 4.0, "the shoulder blends toward the land")


func test_add_mound_is_full_at_the_centre_and_gone_past_its_falloff() -> void:
	var mound := _feature(TerrainFeature.Kind.MOUND, TerrainFeature.Mode.ADD, [Vector2(5, 0)], 2.0, 4.0, 5.0)
	var field := TerrainGenerator.build(_spec([mound]))
	assert_almost_eq(field.height_at(5, 0), 6.0, 0.0001)
	assert_almost_eq(field.height_at(5, 2), 6.0, 0.0001, "full strength inside the width")
	assert_almost_eq(field.height_at(12, 0), 1.0, 0.0001, "7 m out, past width + falloff")
	var mid := field.height_at(9, 0)
	assert_between(mid, 1.01, 5.99, "eases in between")


func test_ramp_path_runs_from_height_to_end_height() -> void:
	var ramp := _feature(TerrainFeature.Kind.PATH, TerrainFeature.Mode.SET,
			[Vector2(-10, 0), Vector2(10, 0)], 1.0, 1.0, 0.0)
	ramp.end_height = 4.0
	var field := TerrainGenerator.build(_spec([ramp]))
	assert_almost_eq(field.height_at(-10, 0), 0.0, 0.0001)
	assert_almost_eq(field.height_at(0, 0), 2.0, 0.0001)
	assert_almost_eq(field.height_at(10, 0), 4.0, 0.0001)


func test_surface_tags_only_the_full_strength_zone() -> void:
	var road := _feature(TerrainFeature.Kind.PATH, TerrainFeature.Mode.SET,
			[Vector2(-15, 0), Vector2(15, 0)], 2.0, 3.0, 1.0)
	road.surface = HeightField.Surface.ROAD
	var field := TerrainGenerator.build(_spec([road]))
	var col := int((0.0 - field.origin.x) / field.cell)
	var row := int((0.0 - field.origin.y) / field.cell)
	assert_eq(field.get_surface(col, row), HeightField.Surface.ROAD)
	assert_eq(field.get_surface(col, row + 2), HeightField.Surface.ROAD)
	assert_eq(field.get_surface(col, row + 3), HeightField.Surface.GRASS, "the shoulder keeps its own")


func test_features_apply_in_order() -> void:
	var mound := _feature(TerrainFeature.Kind.MOUND, TerrainFeature.Mode.ADD, [Vector2.ZERO], 3.0, 2.0, 5.0)
	var pad := _feature(TerrainFeature.Kind.MOUND, TerrainFeature.Mode.SET, [Vector2.ZERO], 1.0, 1.0, 2.0)
	assert_almost_eq(TerrainGenerator.build(_spec([mound, pad])).height_at(0, 0), 2.0, 0.0001)
	assert_almost_eq(TerrainGenerator.build(_spec([pad, mound])).height_at(0, 0), 7.0, 0.0001)
