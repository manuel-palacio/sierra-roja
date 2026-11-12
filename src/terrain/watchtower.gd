class_name Watchtower
extends StaticBody3D
## A timber watchtower: four legs, cross braces, a railed platform and a pitched roof, with a
## ladder up one side. It blocks sight and movement like a building of its footprint (nobody
## climbs it). Goes under Nav/ so the navmesh bake cuts it out; stand() sets it on the ground.

const FOOT := 2.6
const FLOOR := 4.2
const TOP := 6.4
const TIMBER := Color(0.82, 0.72, 0.60)
## Where the lamp of a searchlight is mounted, above the tower's foot.
const LAMP_HEIGHT := 5.3

## The searchlight's sweep: the middle of it in degrees (0 east, 90 south), the swing either
## side, and how far out the spot travels. Used only when the mission is at night.
@export var aim_deg := 0.0
@export var arc_deg := 50.0
@export var reach := 14.0

## The searchlight, once one has been lit.
var searchlight: Searchlight


## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
func stand(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	global_position.y = ground.call(global_position.x, global_position.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(FOOT, TOP, FOOT)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, TOP / 2.0 - 0.3, 0)
	add_child(collision)
	var wood := Surfaces.material(&"planks", TIMBER)
	var h := FOOT / 2.0 - 0.1
	for x in [-h, h]:
		for z in [-h, h]:
			_piece(Vector3(0.18, TOP - 0.6, 0.18), Vector3(x, (TOP - 0.6) / 2.0 - 0.3, z), wood)
	# Braces: a cross on each face below the platform.
	for face in 4:
		var turn := face * PI / 2.0
		for lean in [-1.0, 1.0]:
			var brace := _piece(Vector3(0.09, sqrt(FOOT * FOOT + 3.4 * 3.4), 0.09), Vector3.ZERO, wood)
			brace.transform = Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, lean * atan2(FOOT - 0.2, 3.4)),
					Basis(Vector3.UP, turn) * Vector3(0, 2.0, h))
	_piece(Vector3(FOOT + 0.5, 0.14, FOOT + 0.5), Vector3(0, FLOOR, 0), wood)
	for face in 4:
		var rail := _piece(Vector3(FOOT + 0.5, 0.10, 0.08), Vector3.ZERO, wood)
		rail.transform = Transform3D(Basis(Vector3.UP, face * PI / 2.0), Basis(Vector3.UP, face * PI / 2.0) * Vector3(0, FLOOR + 1.0, h + 0.2))
	_piece(Vector3(FOOT + 1.0, 0.14, FOOT + 1.0), Vector3(0, TOP - 0.4, 0), Surfaces.material(&"roof", Color(0.9, 0.78, 0.7)))
	_piece(Vector3(FOOT * 0.5, 0.3, FOOT * 0.5), Vector3(0, TOP - 0.15, 0), Surfaces.material(&"roof", Color(0.9, 0.78, 0.7)))
	# The ladder up the south side.
	for x in [-0.28, 0.28]:
		_piece(Vector3(0.07, FLOOR + 0.4, 0.07), Vector3(x, FLOOR / 2.0, h + 0.36), wood)
	for i in 9:
		_piece(Vector3(0.6, 0.05, 0.05), Vector3(0, 0.35 + i * 0.45, h + 0.36), wood)


func _piece(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


## Mounts and lights the searchlight. Mission calls this for a night mission, after stand().
func light_up(ground: Callable) -> Searchlight:
	if searchlight != null:
		return searchlight
	searchlight = Searchlight.new()
	searchlight.name = "Searchlight"
	searchlight.aim_deg = aim_deg
	searchlight.arc_deg = arc_deg
	searchlight.reach = reach
	add_child(searchlight)
	searchlight.position = Vector3(0, LAMP_HEIGHT, 0)
	searchlight.setup(ground)
	# The lamp housing.
	_piece(Vector3(0.5, 0.5, 0.5), Vector3(0, LAMP_HEIGHT, 0), Surfaces.material(&"steel", Color(0.7, 0.72, 0.75)))
	return searchlight
