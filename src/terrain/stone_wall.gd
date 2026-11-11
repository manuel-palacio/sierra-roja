class_name StoneWall
extends StaticBody3D
## A dry-stone wall along a polyline, built from blocks that step with the ground. High enough to
## hide someone crawling, low enough to see a standing head over. Goes under Nav/ so the navmesh
## bake cuts it out. The node stays at the origin; `points` are world positions.

## Tint over the stone texture.
const COLOR := Color(0.92, 0.88, 0.82)
## Longest single block, in metres.
const BLOCK_LENGTH := 1.6
## Blocks reach this far into the ground, so a slope shows no gap under them.
const SINK := 0.4

## Polyline on the ground plane (x, z).
@export var points := PackedVector2Array()
@export var wall_height := 1.0
@export var thickness := 0.6

## ground.call(x, z) gives the ground height. Mission calls this before the navmesh bake.
func build(ground: Callable) -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(points)
	for i in points.size() - 1:
		var from := points[i]
		var to := points[i + 1]
		var blocks := maxi(int(ceilf(from.distance_to(to) / BLOCK_LENGTH)), 1)
		for b in blocks:
			var a := from.lerp(to, float(b) / blocks)
			var c := from.lerp(to, float(b + 1) / blocks)
			_add_block(a, c, ground, rng)


func _add_block(a: Vector2, c: Vector2, ground: Callable, rng: RandomNumberGenerator) -> void:
	var mid := (a + c) / 2.0
	var base: float = minf(ground.call(a.x, a.y), ground.call(c.x, c.y))
	var top: float = ground.call(mid.x, mid.y) + wall_height
	var size := Vector3(a.distance_to(c) + 0.05, top - base + SINK, thickness)
	var at := Transform3D(Basis(Vector3.UP, -(c - a).angle()), Vector3(mid.x, top - size.y / 2.0, mid.y))
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = at
	add_child(collision)
	# The drawn block is a little uneven; what blocks sight and feet is the plain box above.
	var mesh := BoxMesh.new()
	mesh.size = size * Vector3(1.0, 1.0, rng.randf_range(0.85, 1.1)) + Vector3(0, rng.randf_range(-0.08, 0.08), 0)
	mesh.material = _stone()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = at
	add_child(instance)


static func _stone() -> StandardMaterial3D:
	return Surfaces.material(&"stone", COLOR)
