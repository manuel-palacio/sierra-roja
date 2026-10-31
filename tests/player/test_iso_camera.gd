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
