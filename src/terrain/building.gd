class_name Building
extends StaticBody3D
## A small rural building made of plain shapes: whitewashed walls under a tiled pitched roof, or,
## as a ruin, broken walls with a doorway and no roof, which can be walked into. Goes under Nav/
## so the navmesh bake cuts it out. Place it by x, z and rotation; build() sets it on the ground.

const WALL_COLOR := Color(0.80, 0.76, 0.68)
const ROOF_COLOR := Color(0.56, 0.27, 0.18)
const RUIN_COLOR := Color(0.62, 0.58, 0.50)
const WALL_THICKNESS := 0.45
const DOOR_WIDTH := 2.6
const EAVES := 0.35
const SINK := 0.6

## Footprint along x, wall height, footprint along z.
@export var size := Vector3(5.0, 3.0, 4.0)
@export var roof_height := 1.4
## Broken walls of uneven height with a doorway in the south wall (+z), and no roof.
@export var ruin := false


## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
func build(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	global_position.y = ground.call(global_position.x, global_position.z)
	if ruin:
		_build_ruin()
	else:
		_add_box(Vector3(0, (size.y - SINK) / 2.0, 0), Vector3(size.x, size.y + SINK, size.z), WALL_COLOR)
		if roof_height > 0.0:
			add_child(_roof())


func _build_ruin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3(size.x, global_position.x, global_position.z))
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var t := WALL_THICKNESS
	# North, west and east walls whole; the south wall in two pieces either side of the doorway.
	var door := (size.x - DOOR_WIDTH) / 2.0
	var walls := [
		[Vector3(0, 0, -hz + t / 2.0), Vector3(size.x, 0, t)],
		[Vector3(-hx + t / 2.0, 0, 0), Vector3(t, 0, size.z)],
		[Vector3(hx - t / 2.0, 0, 0), Vector3(t, 0, size.z)],
		[Vector3(-hx + door / 2.0, 0, hz - t / 2.0), Vector3(door, 0, t)],
		[Vector3(hx - door / 2.0, 0, hz - t / 2.0), Vector3(door, 0, t)],
	]
	for wall in walls:
		var height := size.y * rng.randf_range(0.55, 1.0)
		var centre: Vector3 = wall[0]
		var extent: Vector3 = wall[1]
		_add_box(Vector3(centre.x, (height - SINK) / 2.0, centre.z),
				Vector3(extent.x, height + SINK, extent.z), RUIN_COLOR)


func _add_box(at: Vector3, box_size: Vector3, color: Color) -> void:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


## A pitched roof with its ridge along x, overhanging the walls.
func _roof() -> MeshInstance3D:
	var hx := size.x / 2.0 + EAVES
	var hz := size.z / 2.0 + EAVES
	var y0 := size.y
	var y1 := size.y + roof_height
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [
		[Vector3(-hx, y1, 0), Vector3(hx, y1, 0), Vector3(hx, y0, hz), Vector3(-hx, y0, hz)],
		[Vector3(hx, y1, 0), Vector3(-hx, y1, 0), Vector3(-hx, y0, -hz), Vector3(hx, y0, -hz)],
	]
	for q in quads:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[i])
	for x in [-hx, hx]:
		var gable := [Vector3(x, y0, -hz), Vector3(x, y1, 0), Vector3(x, y0, hz)]
		if x > 0.0:
			gable.reverse()
		for v in gable:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var material := _material(ROOF_COLOR)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Roof"
	instance.mesh = mesh
	return instance


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m
