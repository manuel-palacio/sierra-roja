class_name Sleepers
extends MultiMeshInstance3D
## Railway sleepers laid across the track along x, from from_x to to_x. Display only.

const SIZE := Vector3(0.26, 0.12, 2.3)
const COLOR := Color(0.24, 0.18, 0.13)

@export var from_x := -10.0
@export var to_x := 10.0
@export var spacing := 0.75


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	material.roughness = 1.0
	mesh.material = material
	var n := maxi(int((to_x - from_x) / spacing) + 1, 0)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = n
	for i in n:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(from_x + i * spacing, SIZE.y / 2.0, 0.0)))
