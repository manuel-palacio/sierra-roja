class_name Perception
extends RefCounted
## Vision zones plus line of sight against the world.

## Collision layer 1 is the world (walls, ground, cover). Units live on layer 2, so sight
## rays that mask only the world never hit a unit.
const WORLD_MASK := Unit.LAYER_WORLD


static func sees(guard: Unit, target: Node3D, target_height: float, far_range := -1.0,
		tuning: GuardVision = null) -> Vision.Zone:
	var v := tuning if tuning != null else Vision.defaults()
	var range_m := far_range if far_range > 0.0 else v.far_range
	var eye := guard.global_position + Vector3.UP * v.eye_height
	var aim := target.global_position + Vector3.UP * target_height
	var stance: Unit.Stance = Unit.Stance.CRAWLING if target_height <= v.target_height_crawling \
			else Unit.Stance.STANDING
	if target is Unit:
		stance = (target as Unit).stance
	var zone := Vision.zone(eye, -guard.global_basis.z, aim, stance, range_m, v)
	if zone == Vision.Zone.NONE:
		return zone
	if _ray(guard, eye, aim).has("position"):
		return Vision.Zone.NONE
	return zone


## Overlay shape on the ground plane: the guard's position, then `rays` points across the
## cone, each pulled in to the first wall hit.
static func polygon(guard: Unit, far_range: float, rays := 24, tuning: GuardVision = null) -> PackedVector3Array:
	var v := tuning if tuning != null else Vision.defaults()
	var eye := guard.global_position + Vector3.UP * v.eye_height
	var forward := -guard.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var half := deg_to_rad(v.half_angle_deg)
	var ground_y := guard.global_position.y
	var out := PackedVector3Array()
	out.append(guard.global_position)
	var n := maxi(rays, 2)
	for i in n:
		var dir := forward.rotated(Vector3.UP, lerpf(-half, half, float(i) / float(n - 1)))
		var end := eye + dir * far_range
		var hit := _ray(guard, eye, end)
		var p := hit["position"] as Vector3 if hit.has("position") else end
		out.append(Vector3(p.x, ground_y, p.z))
	return out


## The ground a guard's cone covers, sampled along `rays` rays from `from_m` out to `range_m` every
## `step` metres (plus the two ends), and whether a target of `target_height` standing on each
## sample would be in plain sight of the guard's eye. `ground.call(x, z)` gives the ground height.
## Returns { "points": Array[PackedVector3Array], "visible": Array[PackedByteArray] }, a row per ray.
static func ground_samples(guard: Unit, range_m: float, rays: int, step: float, target_height: float,
		ground: Callable, tuning: GuardVision = null, from_m := 0.0) -> Dictionary:
	var v := tuning if tuning != null else Vision.defaults()
	var eye := guard.global_position + Vector3.UP * v.eye_height
	var forward := -guard.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var half := deg_to_rad(v.half_angle_deg)
	var distances := PackedFloat32Array([from_m])
	var d := (floorf(from_m / step) + 1.0) * step
	while d < range_m - 0.001:
		distances.append(d)
		d += step
	distances.append(range_m)
	var points: Array[PackedVector3Array] = []
	var visible: Array[PackedByteArray] = []
	var n := maxi(rays, 2)
	for i in n:
		var dir := forward.rotated(Vector3.UP, lerpf(-half, half, float(i) / float(n - 1)))
		var row := PackedVector3Array()
		var seen := PackedByteArray()
		for distance in distances:
			var p := guard.global_position
			if distance > 0.0:
				p = eye + dir * distance
				p.y = ground.call(p.x, p.z)
			row.append(p)
			seen.append(1 if distance <= 0.0 or line_clear(guard, eye, p + Vector3.UP * target_height) else 0)
		points.append(row)
		visible.append(seen)
	return { "points": points, "visible": visible }


## True when no world geometry lies between the two points. Units never block.
static func line_clear(from_node: Node3D, from: Vector3, to: Vector3) -> bool:
	return not _ray(from_node, from, to).has("position")


static func _ray(guard: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	return guard.get_world_3d().direct_space_state.intersect_ray(query)
