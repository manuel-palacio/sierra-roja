class_name IsoCamera
extends Camera3D
## Isometric camera: orthographic, pitch -35 degrees, looking from one of four sides (yaw 45
## degrees plus a number of quarter turns). Pans over the ground plane, zooms by orthographic
## size, and turns in quarter steps round the point it looks at, clamped to the mission bounds.

const YAW_DEG := 45.0
const PITCH_DEG := -35.0
const ZOOM_MIN := 15.0
const ZOOM_MAX := 40.0
const ZOOM_STEP := 2.5
const DISTANCE := 60.0
const EDGE_MARGIN := 16.0
const PAN_SPEED := 20.0
## Seconds a quarter turn takes.
const ROTATE_TIME := 0.25

## Ground-plane (x, z) rectangle the focus point may move within.
var bounds := Rect2(-40.0, -30.0, 80.0, 60.0):
	set(value):
		bounds = value
		_apply()
## Ground point the camera looks at.
var focus := Vector3.ZERO
## Edge scrolling is off until the game turns it on (tests and menus leave it off).
var edge_scroll_enabled := false
## False while the pointer is outside the window or the window has lost focus.
var mouse_inside := true

## Which of the four sides the camera looks from: yaw = YAW_DEG + 90 * quarter.
var quarter := 0

var _yaw := YAW_DEG
var _turn_from := YAW_DEG
var _turn_to := YAW_DEG
## 0 to 1 through a turn; 1 when at rest.
var _turn_progress := 1.0
var _mouse_pos := Vector2.ZERO
var _mouse_known := false


func _init() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = ZOOM_MAX
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0.0)
	far = 200.0
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	advance_turn(delta)
	if _mouse_known:
		scroll_step(delta, _mouse_pos, get_viewport().get_visible_rect().size)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_pos = event.position
		_mouse_known = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			mouse_inside = false
		NOTIFICATION_WM_MOUSE_ENTER:
			mouse_inside = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			# The pointer may already be inside; wait for its next move to scroll again.
			mouse_inside = true
			_mouse_known = false


## Screen-space scroll direction (x right, y down, each -1, 0 or 1) for a pointer position.
func edge_scroll_direction(mouse: Vector2, viewport_size: Vector2) -> Vector2:
	if not Rect2(Vector2.ZERO, viewport_size).has_point(mouse):
		return Vector2.ZERO
	var dir := Vector2.ZERO
	if mouse.x < EDGE_MARGIN:
		dir.x = -1.0
	elif mouse.x > viewport_size.x - EDGE_MARGIN:
		dir.x = 1.0
	if mouse.y < EDGE_MARGIN:
		dir.y = -1.0
	elif mouse.y > viewport_size.y - EDGE_MARGIN:
		dir.y = 1.0
	return dir


## One edge-scroll step. Runs while the tree is paused too.
func scroll_step(delta: float, mouse: Vector2, viewport_size: Vector2) -> void:
	if not edge_scroll_enabled or not mouse_inside:
		return
	var dir := edge_scroll_direction(mouse, viewport_size)
	if dir == Vector2.ZERO:
		return
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var ground := right * dir.x + forward * -dir.y
	pan(Vector2(ground.x, ground.z).normalized() * PAN_SPEED * delta)


## Turns the view by quarter turns round the focus: +1 adds 90 degrees of yaw. Eased over
## ROTATE_TIME; a press during a turn carries on to the further quarter.
func rotate_by(step: int) -> void:
	quarter = posmod(quarter + step, 4)
	_turn_from = _yaw
	_turn_to = (_turn_to if _turn_progress < 1.0 else _yaw) + 90.0 * step
	_turn_progress = 0.0


## One step of a turn in progress. Runs while the tree is paused too.
func advance_turn(delta: float) -> void:
	if _turn_progress >= 1.0:
		return
	_turn_progress = minf(_turn_progress + delta / ROTATE_TIME, 1.0)
	if _turn_progress >= 1.0:
		_yaw = YAW_DEG + 90.0 * quarter
		_turn_to = _yaw
	else:
		_yaw = lerpf(_turn_from, _turn_to, smoothstep(0.0, 1.0, _turn_progress))
	rotation_degrees = Vector3(PITCH_DEG, _yaw, 0.0)
	_apply()


## Moves the focus by [param delta] metres on the ground plane (x = east, y = south).
func pan(delta: Vector2) -> void:
	focus += Vector3(delta.x, 0.0, delta.y)
	_apply()


## Positive steps zoom in, negative zoom out.
func zoom_by(step: int) -> void:
	size = clampf(size - step * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


func _apply() -> void:
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	position = focus + basis.z * DISTANCE
