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
## The way into an enterable building: wide enough to stay open once the navmesh is cut back
## from the walls either side.
const ENTRANCE_WIDTH := 2.4
const LOOK_INTERVAL := 0.1

## Footprint along x, wall height, footprint along z.
@export var size := Vector3(5.0, 3.0, 4.0)
@export var roof_height := 1.4
## Broken walls of uneven height with a doorway in the south wall (+z), and no roof.
@export var ruin := false
## Hollow, with a doorway in the south wall (+z): units walk in and out, the walls hide whoever is
## inside from outside, and the roof is lifted off the picture while a specialist is inside.
@export var enterable := false
## Two floors' worth of wall, with a second row of windows. The upper floor is not gone up to.
@export var storeys := 1

## The roof and whatever else is taken off the picture while a specialist is inside.
var _lid: Array[Node3D] = []
var _since_look := 0.0


## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
var _room_lamp: OmniLight3D


func build(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	global_position.y = ground.call(global_position.x, global_position.z)
	_lid.clear()
	if ruin:
		_build_ruin()
		return
	if enterable:
		_build_hollow()
	else:
		_add_box(Vector3(0, (size.y - SINK) / 2.0, 0), Vector3(size.x, size.y + SINK, size.z),
				Surfaces.material(&"plaster", WALL_COLOR))
	if roof_height > 0.0:
		var roof := _roof()
		add_child(roof)
		_lid.append(roof)
	_add_details()


## Whether a point of the ground plane is inside the walls.
func holds(at: Vector3) -> bool:
	var local := global_transform.affine_inverse() * at
	return absf(local.x) < size.x / 2.0 - WALL_THICKNESS and absf(local.z) < size.z / 2.0 - WALL_THICKNESS


## True while the roof is off the picture.
func is_open() -> bool:
	return not _lid.is_empty() and not _lid[0].visible


func _process(delta: float) -> void:
	if not enterable or _lid.is_empty():
		return
	_since_look += delta
	if _since_look < LOOK_INTERVAL:
		return
	_since_look = 0.0
	look_inside()


## Lifts the roof off the picture when a living specialist is inside, and puts it back when not.
## Display only: nothing here changes who can see whom.
func look_inside() -> void:
	var occupied := false
	for node in get_tree().get_nodes_in_group(Specialist.GROUP):
		var s := node as Specialist
		if s.alive and holds(s.global_position):
			occupied = true
	for part in _lid:
		part.visible = not occupied
	if _room_lamp != null:
		_room_lamp.visible = occupied


## Four walls with a doorway in the south one, a floor, and a little furniture.
func _build_hollow() -> void:
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	var t := WALL_THICKNESS
	var plaster := Surfaces.material(&"plaster", WALL_COLOR)
	var door := (size.x - ENTRANCE_WIDTH) / 2.0
	for wall in [
		[Vector3(0, 0, -hz + t / 2.0), Vector3(size.x, 0, t)],
		[Vector3(-hx + t / 2.0, 0, 0), Vector3(t, 0, size.z)],
		[Vector3(hx - t / 2.0, 0, 0), Vector3(t, 0, size.z)],
		[Vector3(-hx + door / 2.0, 0, hz - t / 2.0), Vector3(door, 0, t)],
		[Vector3(hx - door / 2.0, 0, hz - t / 2.0), Vector3(door, 0, t)],
	]:
		var centre: Vector3 = wall[0]
		var extent: Vector3 = wall[1]
		_add_box(Vector3(centre.x, (size.y - SINK) / 2.0, centre.z), Vector3(extent.x, size.y + SINK, extent.z), plaster)
	# The lintel over the doorway goes with the roof, so the way in shows when the roof is off.
	var lintel := _trim(Vector3(0, size.y - 0.35, hz - t / 2.0), Vector3(ENTRANCE_WIDTH, 0.7, t), plaster)
	_lid.append(lintel)
	_add_trim(Vector3(0, 0.03, 0), Vector3(size.x - t * 2.0, 0.06, size.z - t * 2.0), Surfaces.material(&"planks", Color(0.72, 0.62, 0.50)))
	_furnish()


## What makes the room a guardroom: a dado round the walls, a table with its lamp and stools, a
## stove, a rifle rack, a shelf, and bunks where there is room. All display only and all against
## the walls, so the middle and the doorway stay clear.
func _furnish() -> void:
	var t := WALL_THICKNESS
	var west := -size.x / 2.0 + t
	var east := size.x / 2.0 - t
	var north := -size.z / 2.0 + t
	var south := size.z / 2.0 - t
	var wood := Surfaces.material(&"planks", DOOR_COLOR)
	var pale := Surfaces.material(&"planks", Color(0.80, 0.68, 0.52))
	var iron := Surfaces.material(&"steel", Color(0.22, 0.22, 0.24))
	var dado := _flat(Color(0.42, 0.50, 0.44))
	# A painted band along the foot of the three whole walls.
	_add_trim(Vector3(0, 0.5, north + 0.02), Vector3(east - west, 1.0, 0.04), dado)
	_add_trim(Vector3(west + 0.02, 0.5, 0), Vector3(0.04, 1.0, south - north), dado)
	_add_trim(Vector3(east - 0.02, 0.5, 0), Vector3(0.04, 1.0, south - north), dado)
	# A rug in the middle of the floor.
	_add_trim(Vector3(0, 0.07, 0.1), Vector3(minf(2.2, east - west - 2.2), 0.02, 1.3), _flat(Color(0.55, 0.22, 0.18)))
	_add_trim(Vector3(0, 0.075, 0.1), Vector3(minf(1.8, east - west - 2.6), 0.02, 0.9), _flat(Color(0.74, 0.62, 0.42)))
	# The table in the north-west corner, with stools, a map, a bottle and the lamp.
	var table := Vector3(west + 0.85, 0, north + 0.55)
	_add_trim(table + Vector3(0, 0.74, 0), Vector3(1.3, 0.07, 0.75), pale)
	for leg in [Vector2(-0.57, -0.3), Vector2(0.57, -0.3), Vector2(-0.57, 0.3), Vector2(0.57, 0.3)]:
		_add_trim(table + Vector3(leg.x, 0.37, leg.y), Vector3(0.07, 0.72, 0.07), wood)
	for stool in [Vector3(-0.2, 0, 0.75), Vector3(0.95, 0, 0.1)]:
		_add_trim(table + stool + Vector3(0, 0.42, 0), Vector3(0.36, 0.06, 0.36), wood)
		_add_trim(table + stool + Vector3(0, 0.2, 0), Vector3(0.22, 0.4, 0.22), wood)
	_add_trim(table + Vector3(-0.2, 0.785, 0.02), Vector3(0.6, 0.01, 0.42), _flat(Color(0.86, 0.82, 0.68)))
	_add_trim(table + Vector3(0.42, 0.9, -0.2), Vector3(0.08, 0.26, 0.08), _flat(Color(0.16, 0.30, 0.18)))
	_add_trim(table + Vector3(0.3, 0.84, 0.15), Vector3(0.1, 0.14, 0.1), iron)
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, 0.82, 0.45)
	_add_trim(table + Vector3(0.3, 0.97, 0.15), Vector3(0.07, 0.12, 0.07), flame)
	# Lit only while the room is looked into: under its roof the light would leak through the walls.
	_room_lamp = OmniLight3D.new()
	_room_lamp.name = "RoomLamp"
	_room_lamp.light_color = Color(1.0, 0.78, 0.5)
	_room_lamp.light_energy = 1.6
	_room_lamp.omni_range = maxf(size.x, size.z) * 0.8
	_room_lamp.visible = false
	add_child(_room_lamp)
	_room_lamp.position = table + Vector3(0.3, 1.5, 0.15)
	# The stove in the north-east corner, its pipe going up the wall.
	var stove := Vector3(east - 0.45, 0, north + 0.45)
	_add_trim(stove + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), iron)
	_add_trim(stove + Vector3(0, 0.93, 0), Vector3(0.7, 0.06, 0.7), iron)
	_add_trim(stove + Vector3(0.1, (size.y + 0.9) / 2.0, -0.1), Vector3(0.16, size.y - 0.9, 0.16), iron)
	_add_trim(stove + Vector3(0, 0.4, 0.31), Vector3(0.26, 0.2, 0.02), flame)
	_add_trim(stove + Vector3(-0.75, 0.2, 0.05), Vector3(0.6, 0.4, 0.45), pale)  # the log box
	# Rifles racked on the east wall.
	var rack := Vector3(east - 0.1, 0, south - 1.0)
	_add_trim(rack + Vector3(0, 0.25, 0), Vector3(0.2, 0.08, 1.1), wood)
	_add_trim(rack + Vector3(0, 1.0, 0), Vector3(0.12, 0.08, 1.1), wood)
	for i in 3:
		_add_trim(rack + Vector3(-0.04, 0.85, -0.35 + i * 0.35), Vector3(0.07, 1.2, 0.07), iron)
		_add_trim(rack + Vector3(-0.04, 0.5, -0.35 + i * 0.35), Vector3(0.09, 0.45, 0.11), wood)
	# A shelf on the west wall with tins and a helmet, and a coat hung under it.
	var shelf := Vector3(west + 0.14, 1.5, south - 1.0)
	_add_trim(shelf, Vector3(0.28, 0.05, 1.2), wood)
	_add_trim(shelf + Vector3(0, 0.13, -0.4), Vector3(0.16, 0.2, 0.16), _flat(Color(0.62, 0.34, 0.22)))
	_add_trim(shelf + Vector3(0, 0.1, -0.1), Vector3(0.14, 0.15, 0.14), _flat(Color(0.70, 0.66, 0.50)))
	_add_trim(shelf + Vector3(0, 0.1, 0.35), Vector3(0.24, 0.14, 0.26), _flat(Color(0.33, 0.37, 0.28)))
	_add_trim(shelf + Vector3(-0.05, -0.55, 0.2), Vector3(0.1, 0.9, 0.42), _flat(Color(0.36, 0.38, 0.30)))
	if size.x < 6.0:
		return
	# Room for bunks along the back wall: frame, mattress, grey blanket and a pillow.
	var count := int((east - west - 3.2) / 1.1)
	for i in count:
		var bunk := Vector3(west + 2.2 + i * 1.1, 0, north + 1.0)
		_add_trim(bunk + Vector3(0, 0.3, 0), Vector3(0.9, 0.12, 1.95), wood)
		_add_trim(bunk + Vector3(0, 0.6, -0.95), Vector3(0.9, 0.7, 0.06), wood)
		_add_trim(bunk + Vector3(0, 0.42, 0.02), Vector3(0.82, 0.14, 1.8), _flat(Color(0.80, 0.77, 0.68)))
		_add_trim(bunk + Vector3(0, 0.46, 0.3), Vector3(0.84, 0.1, 1.2), _flat(Color(0.42, 0.44, 0.46)))
		_add_trim(bunk + Vector3(0, 0.52, -0.68), Vector3(0.55, 0.1, 0.32), _flat(Color(0.90, 0.88, 0.82)))
		_add_trim(bunk + Vector3(0, 0.2, 1.15), Vector3(0.7, 0.4, 0.4), pale)  # a footlocker


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
	if not enterable:
		var door := Vector3(1.0, minf(2.0, size.y - 0.4), 0.1)
		_add_trim(Vector3(-hx * 0.35, door.y / 2.0, hz + 0.02), door, Surfaces.material(&"planks", DOOR_COLOR))
	var glass := _flat(GLASS_COLOR)
	var frame := Surfaces.material(&"planks", DOOR_COLOR)
	var sill := minf(1.5, size.y / maxi(storeys, 1) - 0.9)
	var windows := []
	for floor_index in maxi(storeys, 1):
		var y := sill + floor_index * size.y / maxi(storeys, 1)
		# Beside the doorway on the ground floor of a house one walks into; over it upstairs.
		var front_x := hx * 0.7 if enterable and floor_index == 0 else hx * 0.45
		windows.append([Vector3(front_x, y, hz + 0.02), Vector3(0.8, 0.8, 0.08)])
		windows.append([Vector3(hx + 0.02, y, 0.0), Vector3(0.08, 0.8, 0.8)])
		windows.append([Vector3(-hx - 0.02, y, 0.0), Vector3(0.08, 0.8, 0.8)])
		if floor_index > 0:
			windows.append([Vector3(-hx * 0.45, y, hz + 0.02), Vector3(0.8, 0.8, 0.08)])
	for window in windows:
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
	_lid.append(_trim(Vector3(0, size.y + roof_height + 0.03, 0), Vector3(size.x + EAVES * 2.0 + 0.1, 0.12, 0.26),
			Surfaces.material(&"roof", RIDGE_COLOR)))
	var lean := Vector3(size.x * 0.5, size.y * 0.62, 1.5)
	_add_trim(Vector3(-size.x * 0.2, lean.y / 2.0, -hz - lean.z / 2.0), lean, Surfaces.material(&"planks", DOOR_COLOR))
	_add_trim(Vector3(-size.x * 0.2, lean.y + 0.08, -hz - lean.z / 2.0 - 0.1), Vector3(lean.x + 0.3, 0.12, lean.z + 0.4),
			Surfaces.material(&"roof", ROOF_COLOR))
	for i in 3:
		_add_trim(Vector3(size.x * 0.28, 0.14 + i * 0.26, -hz - 0.45), Vector3(1.5 - i * 0.3, 0.26, 0.7),
				Surfaces.material(&"bark", Color(0.9, 0.82, 0.72)))
	var chimney := Vector3(hx * 0.5, size.y + roof_height * 0.75, -hz * 0.3)
	_lid.append(_trim(chimney, Vector3(0.5, roof_height * 1.1, 0.5), Surfaces.material(&"stone", RUIN_COLOR)))
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
	_lid.append(smoke)


## A piece that is only looked at: no collision.
func _add_trim(at: Vector3, box_size: Vector3, material: Material) -> void:
	_trim(at, box_size, material)


func _trim(at: Vector3, box_size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


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
