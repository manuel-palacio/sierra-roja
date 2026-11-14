extends GutTest
## Fingers: a tap is a click, a drag scrolls the view and orders nothing, two fingers zoom and
## turn, and the mouse clicks a browser makes up from touches are not counted twice.

var cam: IsoCamera
var input: PlayerInput
var dyn: Specialist
var now := 0.0
var picked := {}


func before_each() -> void:
	cam = IsoCamera.new()
	add_child_autofree(cam)
	dyn = load("res://scenes/units/specialist.tscn").instantiate() as Specialist
	add_child_autofree(dyn)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, [dyn])
	input.picker = func(_pos: Vector2) -> Dictionary: return picked
	input.clock = func() -> float: return now
	picked = { "collider": null, "position": Vector3(6, 0, 2) }
	now = 10.0


func after_each() -> void:
	Touch.set_active(false)


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag(index: int, pos: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = relative
	return e


func _target() -> Vector3:
	return (dyn.get_node("NavigationAgent3D") as NavigationAgent3D).target_position


func _tap(pos := Vector2(200, 200)) -> void:
	input.handle_event(_touch(0, pos, true))
	input.handle_event(_touch(0, pos, false))


func test_a_tap_moves_the_selected_specialist_when_the_finger_lifts() -> void:
	input.handle_event(_touch(0, Vector2(200, 200), true))
	assert_eq(_target(), Vector3.ZERO, "nothing yet: it may become a drag")
	input.handle_event(_touch(0, Vector2(203, 201), false))
	assert_eq(_target(), Vector3(6, 0, 2))
	assert_true(Touch.active(), "and the game knows fingers are in use")


func test_two_taps_close_together_run() -> void:
	_tap(Vector2(200, 200))
	now += 0.3
	_tap(Vector2(225, 190))
	assert_true(dyn.is_running(), "a finger is not held to a mouse's twelve pixels")


func test_a_drag_scrolls_the_view_and_orders_nothing() -> void:
	var before := cam.focus
	input.handle_event(_touch(0, Vector2(200, 200), true))
	input.handle_event(_drag(0, Vector2(260, 200), Vector2(60, 0)))
	input.handle_event(_touch(0, Vector2(260, 200), false))
	assert_eq(_target(), Vector3.ZERO)
	assert_gt(cam.focus.distance_to(before), 0.5)


func test_the_ground_follows_the_finger() -> void:
	var before := cam.focus
	cam.drag(Vector2(100, 0), 720.0)
	var moved := cam.focus - before
	var right := Vector3(cam.basis.x.x, 0, cam.basis.x.z).normalized()
	assert_almost_eq(moved.dot(right), -100.0 * cam.size / 720.0, 0.01, "dragged right, the view goes left")
	before = cam.focus
	cam.drag(Vector2(0, 100), 720.0)
	var forward := Vector3(-cam.basis.z.x, 0, -cam.basis.z.z).normalized()
	assert_gt((cam.focus - before).dot(forward), 100.0 * cam.size / 720.0, "the ground is seen at a slant")


func test_two_fingers_apart_zoom_in_and_together_zoom_out() -> void:
	cam.size = 27.5
	input.handle_event(_touch(0, Vector2(300, 300), true))
	input.handle_event(_touch(1, Vector2(400, 300), true))
	input.handle_event(_drag(1, Vector2(460, 300), Vector2(60, 0)))
	assert_lt(cam.size, 27.5, "apart: closer")
	var close := cam.size
	input.handle_event(_drag(1, Vector2(340, 300), Vector2(-120, 0)))
	assert_gt(cam.size, close, "together: further")
	input.handle_event(_touch(1, Vector2(340, 300), false))
	input.handle_event(_touch(0, Vector2(300, 300), false))
	assert_eq(_target(), Vector3.ZERO, "two fingers are never a tap")


func test_two_fingers_twisted_turn_the_camera_a_quarter() -> void:
	input.handle_event(_touch(0, Vector2(300, 300), true))
	input.handle_event(_touch(1, Vector2(400, 300), true))
	input.handle_event(_drag(1, Vector2(370, 370), Vector2(-30, 70)))
	assert_eq(cam.quarter, 1)
	input.handle_event(_drag(1, Vector2(372, 372), Vector2(2, 2)))
	assert_eq(cam.quarter, 1, "once for the one twist")


func test_a_mouse_click_made_up_from_a_touch_is_not_a_second_order() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(100, 100)
	e.device = InputEvent.DEVICE_ID_EMULATION
	input.handle_event(e)
	assert_eq(_target(), Vector3.ZERO)


func test_a_tap_beside_a_guard_is_a_tap_on_the_guard() -> void:
	var guard := load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(guard)
	guard.global_position = Vector3(4, 0, -4)
	var clicked: Array = []
	input.guard_clicked.connect(func(g: Guard) -> void: clicked.append(g))
	input.screen_of = func(world: Vector3) -> Vector2:
		return Vector2(210, 190) if world.distance_to(guard.global_position) < 2.5 else Vector2(900, 900)
	_tap(Vector2(200, 200))
	assert_eq(clicked, [guard])
	assert_eq(_target(), Vector3.ZERO)
