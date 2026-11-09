extends GutTest

var cam: IsoCamera


func before_each() -> void:
	cam = IsoCamera.new()
	cam.bounds = Rect2(-40, -30, 80, 60)
	add_child_autofree(cam)


func test_orthographic_iso_angles() -> void:
	assert_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_almost_eq(cam.rotation_degrees.y, 45.0, 0.01)
	assert_almost_eq(cam.rotation_degrees.x, -35.0, 0.01)


func test_zoom_clamped() -> void:
	cam.zoom_by(100)
	assert_almost_eq(cam.size, 15.0, 0.001)
	cam.zoom_by(-100)
	assert_almost_eq(cam.size, 40.0, 0.001)


func test_zoom_step_changes_size() -> void:
	var before := cam.size
	cam.zoom_by(1)
	assert_lt(cam.size, before)


func test_pan_moves_focus_and_clamps() -> void:
	cam.pan(Vector2(5, -3))
	assert_almost_eq(cam.focus.x, 5.0, 0.001)
	assert_almost_eq(cam.focus.z, -3.0, 0.001)
	cam.pan(Vector2(1000, 1000))
	assert_almost_eq(cam.focus.x, 40.0, 0.001)
	assert_almost_eq(cam.focus.z, 30.0, 0.001)
	cam.pan(Vector2(-1000, -1000))
	assert_almost_eq(cam.focus.x, -40.0, 0.001)
	assert_almost_eq(cam.focus.z, -30.0, 0.001)


func test_camera_looks_at_focus() -> void:
	cam.pan(Vector2(10, 4))
	var forward := -cam.global_transform.basis.z
	var to_focus := (cam.focus - cam.global_position).normalized()
	assert_true(forward.is_equal_approx(to_focus))


# --- Rotation in quarter turns ---

func _camera() -> IsoCamera:
	var c := IsoCamera.new()
	add_child_autofree(c)
	c.bounds = Rect2(-40, -30, 80, 60)
	c.current = true
	return c


func _finish_turn(c: IsoCamera) -> void:
	c.advance_turn(IsoCamera.ROTATE_TIME * 0.5)
	c.advance_turn(IsoCamera.ROTATE_TIME * 0.6)


func test_a_quarter_turn_swings_the_view_round_the_same_spot() -> void:
	var c := _camera()
	c.pan(Vector2(7, -4))
	var focus := c.focus
	c.rotate_by(1)
	assert_eq(c.quarter, 1)
	c.advance_turn(IsoCamera.ROTATE_TIME * 0.5)
	assert_between(c.rotation_degrees.y, 46.0, 134.0, "part of the way round, eased")
	c.advance_turn(IsoCamera.ROTATE_TIME * 0.6)
	assert_almost_eq(c.rotation_degrees.y, 135.0, 0.001)
	assert_almost_eq(c.rotation_degrees.x, IsoCamera.PITCH_DEG, 0.001, "still looking down at the same angle")
	assert_eq(c.focus, focus)
	assert_almost_eq(c.position, focus + c.basis.z * IsoCamera.DISTANCE, Vector3.ONE * 0.001)


func test_four_turns_come_back_to_where_they_began() -> void:
	var c := _camera()
	var start := c.transform
	for i in 4:
		c.rotate_by(1)
		_finish_turn(c)
	assert_eq(c.quarter, 0)
	assert_almost_eq(c.transform.origin, start.origin, Vector3.ONE * 0.001)
	assert_almost_eq(c.transform.basis.z, start.basis.z, Vector3.ONE * 0.0001)
	c.rotate_by(-1)
	assert_eq(c.quarter, 3)
	_finish_turn(c)
	assert_almost_eq(c.rotation_degrees.y, 315.0, 0.001)


func test_a_second_press_during_a_turn_goes_two_quarters() -> void:
	var c := _camera()
	c.rotate_by(1)
	c.advance_turn(IsoCamera.ROTATE_TIME * 0.3)
	c.rotate_by(1)
	_finish_turn(c)
	assert_eq(c.quarter, 2)
	assert_almost_eq(c.rotation_degrees.y, 225.0, 0.001)
	assert_lt(c.basis.z.x, 0.0, "now looking from the other side")


func test_edge_scroll_follows_the_screen_in_every_orientation() -> void:
	var c := _camera()
	c.edge_scroll_enabled = true
	var view := Vector2(1280, 800)
	for q in 4:
		var before := c.focus
		c.scroll_step(0.1, Vector2(view.x - 2, view.y / 2.0), view)  # pointer at the right edge
		var moved := c.focus - before
		var right := Vector3(c.basis.x.x, 0, c.basis.x.z).normalized()
		assert_almost_eq(moved.normalized(), right, Vector3.ONE * 0.001, "quarter %d: right edge scrolls right" % q)
		assert_almost_eq(moved.length(), IsoCamera.PAN_SPEED * 0.1, 0.001)
		before = c.focus
		c.scroll_step(0.1, Vector2(view.x / 2.0, 2), view)  # pointer at the top edge
		var away := Vector3(-c.basis.z.x, 0, -c.basis.z.z).normalized()
		assert_almost_eq((c.focus - before).normalized(), away, Vector3.ONE * 0.001, "quarter %d: top edge scrolls away" % q)
		c.pan(Vector2(-c.focus.x, -c.focus.z))
		c.rotate_by(1)
		_finish_turn(c)


func test_the_screen_centre_is_the_focus_in_every_orientation() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(200, 1, 200)
	ground.add_child(shape)
	add_child_autofree(ground)
	ground.position = Vector3(0, -0.5, 0)
	var c := _camera()
	c.pan(Vector2(12, 5))
	await wait_physics_frames(2)
	var centre := get_viewport().get_visible_rect().size / 2.0
	for q in 4:
		var hit := Picker.pick(c, centre)
		assert_true(hit.has("position"), "quarter %d" % q)
		if hit.has("position"):
			assert_lt((hit["position"] as Vector3).distance_to(c.focus), 0.5, "quarter %d: the click lands on the focus" % q)
		c.rotate_by(1)
		_finish_turn(c)
