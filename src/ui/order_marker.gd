class_name OrderMarker
extends Node3D
## Shows where a move order landed: a ring on the ground that closes in and fades, two rings for a
## run. Display only. Drawn over whatever is in front, so an order behind a tree still shows.

const DURATION := 0.6
const LIFT := 0.1
const COLOR := Color(0.75, 1.0, 0.8)
const START_SCALE := 1.0
const END_SCALE := 0.35
## The second ring of a run order starts this much wider.
const RUN_RING_SCALE := 1.6

var _age := 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nothing to animate until an order is shown.
	set_process(false)


func show_at(pos: Vector3, run: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_age = 0.0
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.albedo_color = COLOR
	for i in (2 if run else 1):
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.62 * (RUN_RING_SCALE if i == 1 else 1.0)
		mesh.outer_radius = 0.72 * (RUN_RING_SCALE if i == 1 else 1.0)
		mesh.rings = 24
		mesh.ring_segments = 4
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = _material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = pos + Vector3.UP * LIFT
	set_process(true)


func _process(delta: float) -> void:
	if _material == null:
		return
	_age += delta
	if _age >= DURATION:
		for child in get_children():
			child.queue_free()
		set_process(false)
		return
	var t := _age / DURATION
	var size := lerpf(START_SCALE, END_SCALE, t)
	for child in get_children():
		(child as Node3D).scale = Vector3(size, 1.0, size)
	_material.albedo_color.a = 1.0 - t * t
