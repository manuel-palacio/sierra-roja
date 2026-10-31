class_name IsoCamera
extends Camera3D
## Fixed isometric camera: orthographic, yaw 45 degrees, pitch -35 degrees.
## Pans over the ground plane and zooms by orthographic size, clamped to the mission bounds.

const YAW_DEG := 45.0
const PITCH_DEG := -35.0
const ZOOM_MIN := 15.0
const ZOOM_MAX := 40.0
const ZOOM_STEP := 2.5
const DISTANCE := 60.0

## Ground-plane (x, z) rectangle the focus point may move within.
var bounds := Rect2(-40.0, -30.0, 80.0, 60.0):
	set(value):
		bounds = value
		_apply()
## Ground point the camera looks at.
var focus := Vector3.ZERO


func _init() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = ZOOM_MAX
	rotation_degrees = Vector3(PITCH_DEG, YAW_DEG, 0.0)
	far = 200.0


func _ready() -> void:
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
