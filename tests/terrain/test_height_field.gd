extends GutTest


func _flat(h: float) -> HeightField:
	var f := HeightField.new(Vector2(-2, -3), 1.0, 6, 5)
	for r in f.rows:
		for c in f.cols:
			f.set_h(c, r, h)
	return f


## Rises 1 m per metre in x, from 0 at the origin.
func _ramp() -> HeightField:
	var f := HeightField.new(Vector2.ZERO, 1.0, 6, 5)
	for r in f.rows:
		for c in f.cols:
			f.set_h(c, r, float(c))
	return f


func test_rect_covers_the_vertices() -> void:
	assert_eq(_flat(0.0).rect(), Rect2(-2, -3, 5, 4))


func test_flat_field_is_its_height_everywhere_with_no_slope() -> void:
	var f := _flat(2.5)
	for p in [Vector2(-2, -3), Vector2(0.3, -0.7), Vector2(3, 1)]:
		assert_almost_eq(f.height_at(p.x, p.y), 2.5, 0.0001)
		assert_almost_eq(f.slope_deg_at(p.x, p.y), 0.0, 0.01)


func test_ramp_height_and_slope() -> void:
	var f := _ramp()
	assert_almost_eq(f.height_at(2.5, 1.2), 2.5, 0.0001)
	assert_almost_eq(f.slope_deg_at(2.5, 1.2), 45.0, 0.01)


func test_outside_the_rect_returns_the_edge_height() -> void:
	var f := _ramp()
	assert_almost_eq(f.height_at(-10.0, 1.0), 0.0, 0.0001)
	assert_almost_eq(f.height_at(99.0, -50.0), 5.0, 0.0001)


func test_quad_centre_is_the_mean_of_the_diagonal_corners() -> void:
	var f := _flat(0.0)
	f.set_h(0, 0, 4.0)   # diagonal corners of the first quad: (0,0) and (1,1)
	f.set_h(1, 1, 2.0)
	f.set_h(1, 0, 100.0)
	f.set_h(0, 1, -100.0)
	assert_almost_eq(f.height_at(-1.5, -2.5), 3.0, 0.0001)


func test_vertex_and_surface_round_trip() -> void:
	var f := _flat(1.0)
	assert_eq(f.vertex(2, 1), Vector3(0, 1, -2))
	assert_eq(f.get_surface(2, 1), HeightField.Surface.GRASS)
	f.set_surface(2, 1, HeightField.Surface.ROAD)
	assert_eq(f.get_surface(2, 1), HeightField.Surface.ROAD)
	assert_eq(f.get_h(-5, 99), 1.0, "indices clamp to the grid")
