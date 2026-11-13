class_name Snowfall
extends CPUParticles3D
## Falling snow over whatever the camera is looking at: a capped handful of small white flakes
## from a box above the view. Display only: it stops nothing, hides nothing and casts no shadow.

## Kept small: the browser build draws these on one thread with everything else.
const MAX_FLAKES := 260
## The box the flakes start in, centred this far above what the camera looks at.
const HEIGHT := 16.0
const SPREAD := Vector3(24.0, 1.0, 17.0)

var _camera: IsoCamera


func _init() -> void:
	amount = MAX_FLAKES
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = SPREAD
	direction = Vector3(0.08, -1.0, 0.04)
	spread = 6.0
	gravity = Vector3.ZERO
	initial_velocity_min = 2.6
	initial_velocity_max = 3.4
	scale_amount_min = 0.7
	scale_amount_max = 1.3
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.96, 0.97, 1.0)
	white.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = white
	mesh = flake


## Keeps the snow over the place this camera looks at.
func follow(camera: IsoCamera) -> void:
	_camera = camera
	_ride()


func _process(_delta: float) -> void:
	_ride()


func _ride() -> void:
	if _camera != null and is_instance_valid(_camera) and is_inside_tree():
		global_position = _camera.focus + Vector3.UP * HEIGHT
