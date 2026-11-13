class_name TelegraphPole
extends Node3D
## A telegraph pole beside the railway: a post, a crossarm with two insulators, and the wires on
## to the next pole. Display only. Place it by x and z; settle() stands it on the ground.

const HEIGHT := 6.2
const ARM := 1.5
const POST_COLOR := Color(0.62, 0.55, 0.48)
const WIRE_COLOR := Color(0.08, 0.08, 0.09)

## Where the next pole stands (x, z), to string the wires to. Vector2.INF for the last of a line.
@export var wire_to := Vector2.INF

static var _wire: StandardMaterial3D

var _wires: Array[MeshInstance3D] = []


## ground.call(x, z) gives the ground height. Mission calls this once its land exists.
func settle(ground: Callable) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_wires.clear()
	global_position.y = ground.call(global_position.x, global_position.z)
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.13
	post.height = HEIGHT + 0.5
	post.radial_segments = 8
	post.rings = 1
	post.material = Surfaces.material(&"bark", POST_COLOR)
	_add(post, Vector3(0, HEIGHT / 2.0 - 0.25, 0))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.1, 0.1, ARM)
	arm.material = Surfaces.material(&"planks", POST_COLOR)
	_add(arm, Vector3(0, HEIGHT - 0.5, 0))
	for side in [-1.0, 1.0]:
		var cup := CylinderMesh.new()
		cup.top_radius = 0.04
		cup.bottom_radius = 0.06
		cup.height = 0.14
		cup.radial_segments = 6
		cup.rings = 1
		cup.material = _wire_material()
		_add(cup, Vector3(0, HEIGHT - 0.38, side * (ARM / 2.0 - 0.12)))
	if wire_to == Vector2.INF:
		return
	var far := Vector3(wire_to.x, ground.call(wire_to.x, wire_to.y), wire_to.y) - global_position
	for side in [-1.0, 1.0]:
		var from := Vector3(0, HEIGHT - 0.3, side * (ARM / 2.0 - 0.12))
		var to := far + from
		var wire := BoxMesh.new()
		wire.size = Vector3(0.02, 0.02, from.distance_to(to))
		wire.material = _wire_material()
		var instance := MeshInstance3D.new()
		instance.mesh = wire
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_wires.append(instance)
		# Turned in the pole's own space, which may itself be turned.
		instance.transform = Transform3D(Basis.looking_at(global_basis.inverse() * (to - from), Vector3.UP),
				global_basis.inverse() * ((from + to) / 2.0))


func _add(mesh: Mesh, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


static func _wire_material() -> StandardMaterial3D:
	if _wire == null:
		_wire = StandardMaterial3D.new()
		_wire.albedo_color = WIRE_COLOR
		_wire.roughness = 0.6
	return _wire


## The wires from this pole on to the next.
func wires() -> Array[MeshInstance3D]:
	return _wires


## The line is cut here: the wires on to the next pole are gone.
func drop_wire() -> void:
	for wire in _wires:
		wire.visible = false


## And up again, for a load from before it was cut.
func raise_wire() -> void:
	for wire in _wires:
		wire.visible = true
