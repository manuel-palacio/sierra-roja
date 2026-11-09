class_name SelectionRing
extends MeshInstance3D
## The ring at a specialist's feet, in that specialist's colour: bright and slowly pulsing on the
## selected one, dim on the other. Drawn over whatever is in front, so it also says where a
## specialist is when a tree hides them. Display only.

const DIM_ALPHA := 0.35
const PULSE_PER_SECOND := 0.8
const PULSE_SIZE := 0.12

@export var color := Color(1.0, 0.3, 0.25)
var selected := false

var _time := 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = color
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0.0)


func _process(delta: float) -> void:
	var material := material_override as StandardMaterial3D
	if selected:
		_time += delta
		var size := 1.0 + sin(_time * TAU * PULSE_PER_SECOND) * PULSE_SIZE
		scale = Vector3(size, 1.0, size)
		material.albedo_color = Color(color, 1.0)
	else:
		_time = 0.0
		scale = Vector3.ONE
		material.albedo_color = Color(color, DIM_ALPHA)
