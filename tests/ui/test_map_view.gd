extends GutTest
## The map view: M shows the whole ground and puts the view back, and the overlay knows the beats.

var cam: IsoCamera
var input: PlayerInput
var mission: Mission
var specs: Array[Specialist]


func before_each() -> void:
	mission = load("res://tests/fixtures/flat_bridge.tscn").instantiate()
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	cam = IsoCamera.new()
	cam.bounds = mission.bounds_rect
	add_child_autofree(cam)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, specs)


func after_each() -> void:
	get_tree().paused = false


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func test_m_shows_the_whole_ground_and_m_again_puts_the_view_back() -> void:
	cam.size = 22.5
	cam.pan(Vector2(7, -4))
	var focus := cam.focus
	input.handle_event(_key(KEY_M))
	assert_true(cam.map_view)
	assert_gt(cam.size, IsoCamera.ZOOM_MAX - 0.01)
	var centre := mission.bounds_rect.get_center()
	assert_almost_eq(cam.focus.x, centre.x, 0.01)
	cam.pan(Vector2(5, 5))
	cam.zoom_by(3)
	assert_almost_eq(cam.focus.x, centre.x, 0.01, "the map does not scroll")
	input.handle_event(_key(KEY_M))
	assert_false(cam.map_view)
	assert_eq(cam.size, 22.5)
	assert_eq(cam.focus, focus)


func test_the_map_works_while_paused() -> void:
	input.set_paused(true)
	input.handle_event(_key(KEY_M))
	assert_true(cam.map_view)


func test_the_overlay_shows_only_in_the_map_view_and_knows_each_beat() -> void:
	var view := MapView.new()
	add_child_autofree(view)
	view.setup(cam, mission, specs)
	view._process(0.0)
	assert_false(view.visible)
	cam.toggle_map_view()
	view._process(0.0)
	assert_true(view.visible)
	var walkers := mission.guards().filter(func(g: Guard) -> bool: return g.route_size() > 1)
	assert_eq(view.beats().size(), walkers.size())
	for guard in walkers:
		assert_eq((view.beats()[guard] as PackedVector2Array).size(), guard.route_size())
