class_name SettlementProp
extends StaticBody3D
## The things that make a guarded place look lived in: a parked truck, a well, a haystack, a
## washing line. All but the washing line are solid: they block sight and movement like a box of
## their size, and the navmesh bake cuts them out (so they go under Nav/). stand() sets one on the
## ground.

## Kind -> the box that makes it solid (zero for none).
const KINDS := {
	&"truck": Vector3(2.2, 2.5, 5.2),
	&"well": Vector3(1.7, 1.1, 1.7),
	&"haystack": Vector3(2.6, 2.2, 2.6),
	&"washing_line": Vector3.ZERO,
}
const CANVAS := Color(0.44, 0.47, 0.34)
const PAINT := Color(0.30, 0.36, 0.28)
const HAY := Color(0.78, 0.66, 0.32)

@export var kind := &"well"


## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
func stand(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	global_position.y = ground.call(global_position.x, global_position.z)
	var solid: Vector3 = KINDS.get(kind, Vector3.ZERO)
	if solid != Vector3.ZERO:
		var shape := BoxShape3D.new()
		shape.size = solid
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0, solid.y / 2.0 - 0.2, 0)
		add_child(collision)
	match kind:
		&"truck":
			_truck()
		&"well":
			_well()
		&"haystack":
			_haystack()
		&"washing_line":
			_washing_line()


func _truck() -> void:
	var paint := _flat(PAINT)
	_box(Vector3(2.0, 0.25, 5.0), Vector3(0, 0.85, 0), _flat(Color(0.14, 0.14, 0.13)))  # chassis
	_box(Vector3(2.0, 1.25, 1.5), Vector3(0, 1.6, 1.55), paint)  # cab
	_box(Vector3(1.7, 0.75, 1.1), Vector3(0, 1.3, 2.75), paint)  # bonnet
	_box(Vector3(1.8, 0.5, 0.06), Vector3(0, 1.85, 2.31), _flat(Color(0.10, 0.13, 0.17)))  # windscreen
	_box(Vector3(2.1, 0.5, 3.0), Vector3(0, 1.2, -0.95), Surfaces.material(&"planks", Color(0.62, 0.58, 0.46)))  # bed
	_box(Vector3(2.05, 1.0, 2.9), Vector3(0, 1.95, -0.95), _flat(CANVAS))  # tilt
	for x in [-1.02, 1.02]:
		for z in [1.9, -1.5]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.5
			wheel.bottom_radius = 0.5
			wheel.height = 0.3
			wheel.radial_segments = 12
			wheel.rings = 1
			wheel.material = _flat(Color(0.07, 0.07, 0.07))
			var instance := MeshInstance3D.new()
			instance.mesh = wheel
			instance.transform = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(x, 0.5, z))
			add_child(instance)


func _well() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 0.8
	ring.bottom_radius = 0.85
	ring.height = 0.95
	ring.radial_segments = 12
	ring.rings = 1
	ring.material = Surfaces.material(&"stone", Color(0.9, 0.86, 0.8))
	_mesh(ring, Vector3(0, 0.35, 0))
	var water := CylinderMesh.new()
	water.top_radius = 0.62
	water.bottom_radius = 0.62
	water.height = 0.04
	water.radial_segments = 12
	water.rings = 1
	water.material = _flat(Color(0.05, 0.10, 0.12))
	_mesh(water, Vector3(0, 0.84, 0))
	var wood := Surfaces.material(&"planks", Color(0.72, 0.62, 0.50))
	for x in [-0.78, 0.78]:
		_box(Vector3(0.1, 1.7, 0.1), Vector3(x, 1.2, 0), wood)
	_box(Vector3(1.75, 0.09, 0.09), Vector3(0, 1.85, 0), wood)
	_box(Vector3(2.0, 0.08, 1.1), Vector3(0, 2.15, 0), Surfaces.material(&"roof", Color(0.9, 0.78, 0.7)))
	_box(Vector3(0.24, 0.26, 0.24), Vector3(0.2, 1.25, 0), wood)  # the bucket
	_box(Vector3(0.02, 0.6, 0.02), Vector3(0.2, 1.6, 0), _flat(Color(0.3, 0.26, 0.2)))


func _haystack() -> void:
	var hay := _flat(HAY)
	var body := CylinderMesh.new()
	body.top_radius = 1.05
	body.bottom_radius = 1.3
	body.height = 1.4
	body.radial_segments = 10
	body.rings = 1
	body.material = hay
	_mesh(body, Vector3(0, 0.6, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05
	cap.bottom_radius = 1.15
	cap.height = 1.0
	cap.radial_segments = 10
	cap.rings = 1
	cap.material = _flat(HAY.darkened(0.12))
	_mesh(cap, Vector3(0, 1.8, 0))


func _washing_line() -> void:
	var wood := Surfaces.material(&"planks", Color(0.72, 0.62, 0.50))
	for x in [-2.2, 2.2]:
		_box(Vector3(0.09, 2.1, 0.09), Vector3(x, 0.95, 0), wood)
	_box(Vector3(4.4, 0.02, 0.02), Vector3(0, 1.95, 0), _flat(Color(0.2, 0.2, 0.2)))
	var cloths := [Color(0.90, 0.88, 0.82), Color(0.42, 0.50, 0.66), Color(0.86, 0.82, 0.70), Color(0.62, 0.30, 0.26)]
	for i in cloths.size():
		var cloth := _box(Vector3(0.7, 0.75 + 0.12 * (i % 2), 0.03), Vector3(-1.5 + i * 1.0, 1.55 - 0.06 * (i % 2), 0), _flat(cloths[i]))
		cloth.rotation.x = 0.08 * (1 if i % 2 == 0 else -1)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return _mesh(mesh, at)


func _mesh(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


static func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m
