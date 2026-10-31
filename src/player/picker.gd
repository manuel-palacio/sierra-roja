class_name Picker
extends RefCounted
## Mouse picking: a ray from the camera through a screen point against the world and unit
## layers. A separate helper so tests can drive it without a window.

const MASK := Unit.LAYER_WORLD | Unit.LAYER_UNITS


## Returns { "collider": Object, "position": Vector3 } for the first hit, or {} for none.
static func pick(cam: Camera3D, screen_pos: Vector2, mask := MASK) -> Dictionary:
	var world := cam.get_world_3d()
	if world == null:
		return {}
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * cam.far
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return { "collider": hit["collider"], "position": hit["position"] }
