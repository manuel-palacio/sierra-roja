class_name Building
extends StaticBody3D
## A small rural building made of plain shapes: whitewashed walls under a tiled pitched roof, or,
## as a ruin, broken walls with a doorway and no roof, which can be walked into. Goes under Nav/
## so the navmesh bake cuts it out. Place it by x, z and rotation; build() sets it on the ground.

## Tints over the plaster, roof-tile and stone textures.
const WALL_COLOR := Color(1.0, 0.96, 0.88)
const ROOF_COLOR := Color(0.95, 0.80, 0.72)
const RUIN_COLOR := Color(0.85, 0.80, 0.72)
const DOOR_COLOR := Color(0.45, 0.33, 0.24)
const GLASS_COLOR := Color(0.10, 0.12, 0.16)
const SMOKE_COLOR := Color(0.75, 0.75, 0.78, 0.35)
const SHUTTER_COLOR := Color(0.36, 0.46, 0.34)
const RIDGE_COLOR := Color(0.78, 0.62, 0.55)
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
		_add_box(Vector3(0, (size.y - SINK) / 2.0, 0), Vector3(size.x, size.y + SINK, size.z),
				Surfaces.material(&"plaster", WALL_COLOR))
		if roof_height > 0.0:
			add_child(_roof())
		_add_details()


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
				Vector3(extent.x, height + SINK, extent.z), Surfaces.material(&"stone", RUIN_COLOR))


## What makes it a house and not a box: a door and a window in the south wall (+z), a window in
## each end, a stone footing, and a chimney with a thread of smoke. All display only.
func _add_details() -> void:
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var door := Vector3(1.0, minf(2.0, size.y - 0.4), 0.1)
	_add_trim(Vector3(-hx * 0.35, door.y / 2.0, hz + 0.02), door, Surfaces.material(&"planks", DOOR_COLOR))
	var glass := _flat(GLASS_COLOR)
	var frame := Surfaces.material(&"planks", DOOR_COLOR)
	var sill := minf(1.5, size.y - 0.9)
	for window in [
		[Vector3(hx * 0.45, sill, hz + 0.02), Vector3(0.8, 0.8, 0.08)],
		[Vector3(hx + 0.02, sill, 0.0), Vector3(0.08, 0.8, 0.8)],
		[Vector3(-hx - 0.02, sill, 0.0), Vector3(0.08, 0.8, 0.8)],
	]:
		var at: Vector3 = window[0]
		var pane: Vector3 = window[1]
		_add_trim(at, pane, glass)
		# A shutter folded back on either side of it.
		var along := Vector3(1, 0, 0) if pane.x > 0.1 else Vector3(0, 0, 1)
		var leaf := Vector3(0.36, 0.86, 0.05) if pane.x > 0.1 else Vector3(0.05, 0.86, 0.36)
		for side in [-1.0, 1.0]:
			_add_trim(at + along * side * 0.6, leaf, Surfaces.material(&"planks", SHUTTER_COLOR))
		# A sill under it.
		var ledge := Vector3(pane.x + 0.2 if pane.x > 0.1 else 0.16, 0.08, pane.z + 0.2 if pane.z > 0.1 else 0.16)
		_add_trim(at + Vector3(0, -pane.y / 2.0 - 0.04, 0), ledge, frame)
	_add_trim(Vector3(0, 0.2 - SINK / 2.0, 0), Vector3(size.x + 0.16, 0.4 + SINK, size.z + 0.16),
			Surfaces.material(&"stone", RUIN_COLOR))
	if roof_height <= 0.0:
		return
	# A row of capping tiles along the ridge, and a lean-to against the north wall with a wood pile.
	_add_trim(Vector3(0, size.y + roof_height + 0.03, 0), Vector3(size.x + EAVES * 2.0 + 0.1, 0.12, 0.26),
			Surfaces.material(&"roof", RIDGE_COLOR))
	var lean := Vector3(size.x * 0.5, size.y * 0.62, 1.5)
	_add_trim(Vector3(-size.x * 0.2, lean.y / 2.0, -hz - lean.z / 2.0), lean, Surfaces.material(&"planks", DOOR_COLOR))
	_add_trim(Vector3(-size.x * 0.2, lean.y + 0.08, -hz - lean.z / 2.0 - 0.1), Vector3(lean.x + 0.3, 0.12, lean.z + 0.4),
			Surfaces.material(&"roof", ROOF_COLOR))
	for i in 3:
		_add_trim(Vector3(size.x * 0.28, 0.14 + i * 0.26, -hz - 0.45), Vector3(1.5 - i * 0.3, 0.26, 0.7),
				Surfaces.material(&"bark", Color(0.9, 0.82, 0.72)))
	var chimney := Vector3(hx * 0.5, size.y + roof_height * 0.75, -hz * 0.3)
	_add_trim(chimney, Vector3(0.5, roof_height * 1.1, 0.5), Surfaces.material(&"stone", RUIN_COLOR))
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = chimney + Vector3(0, roof_height * 0.6, 0)
	smoke.amount = 14
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.direction = Vector3(0.25, 1.0, 0.1)
	smoke.spread = 8.0
	smoke.gravity = Vector3.ZERO
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.3
	var puff := SphereMesh.new()
	puff.radius = 0.3
	puff.height = 0.6
	puff.radial_segments = 6
	puff.rings = 3
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = SMOKE_COLOR
	puff.material = haze
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)


## A piece that is only looked at: no collision.
func _add_trim(at: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.3
	return m


func _add_box(at: Vector3, box_size: Vector3, material: Material) -> void:
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
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
	var material := Surfaces.material(&"roof", ROOF_COLOR).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Roof"
	instance.mesh = mesh
	return instance
