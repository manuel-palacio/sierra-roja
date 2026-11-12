class_name Cart
extends StaticBody3D
## A two-wheeled farm cart, shafts down. Low enough to lie behind, too tall to walk over: it
## blocks like a crate of its size. Goes under Nav/; stand() sets it on the ground.

const BED := Vector3(1.5, 0.5, 2.6)
const WHEEL := 0.62
const TIMBER := Color(0.78, 0.66, 0.52)


## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
func stand(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	global_position.y = ground.call(global_position.x, global_position.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(BED.x + 0.5, 1.5, BED.z)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 0.55, 0)
	add_child(collision)
	var wood := Surfaces.material(&"planks", TIMBER)
	_box(Vector3(BED.x, 0.1, BED.z), Vector3(0, WHEEL + 0.1, 0), wood)
	for x in [-BED.x / 2.0, BED.x / 2.0]:
		_box(Vector3(0.08, BED.y, BED.z), Vector3(x, WHEEL + 0.1 + BED.y / 2.0, 0), wood)
	_box(Vector3(BED.x, BED.y, 0.08), Vector3(0, WHEEL + 0.1 + BED.y / 2.0, -BED.z / 2.0), wood)
	for x in [-0.45, 0.45]:
		var shaft := _box(Vector3(0.08, 0.08, 2.2), Vector3.ZERO, wood)
		shaft.transform = Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(x, WHEEL - 0.28, BED.z / 2.0 + 0.95))
	for x in [-BED.x / 2.0 - 0.14, BED.x / 2.0 + 0.14]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = WHEEL
		wheel.bottom_radius = WHEEL
		wheel.height = 0.1
		wheel.radial_segments = 14
		wheel.rings = 1
		wheel.material = Surfaces.material(&"planks", Color(0.5, 0.42, 0.34))
		var instance := MeshInstance3D.new()
		instance.mesh = wheel
		instance.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(x, WHEEL, -0.2))
		add_child(instance)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance
