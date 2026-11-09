class_name Picker
extends RefCounted
## Mouse picking: a ray from the camera through a screen point against the unit layer, then the
## world layer. A separate helper so tests can drive it without a window.

const MASK := Unit.LAYER_WORLD | Unit.LAYER_UNITS


## Returns { "collider": Object, "position": Vector3 } for what the pointer is on, or {} for
## nothing. A unit under the pointer wins over any world geometry in front of it: units show
## through walls and trees as silhouettes, and a silhouette can be clicked.
static func pick(cam: Camera3D, screen_pos: Vector2, mask := MASK) -> Dictionary:
	var world := cam.get_world_3d()
	if world == null:
		return {}
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * cam.far
	for layer in [mask & Unit.LAYER_UNITS, mask & ~Unit.LAYER_UNITS]:
		if layer == 0:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, to, layer)
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return { "collider": hit["collider"], "position": hit["position"] }
	return {}
