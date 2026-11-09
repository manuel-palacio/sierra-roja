class_name VisionOverlay
extends Node3D
## Draws one guard's vision on the ground, following the land: the near zone in red, the far zone
## (a ring around it) in yellow. Unlit and translucent so it shows in the Compatibility renderer,
## a little above the ground. Rebuilt at most REBUILD_INTERVAL seconds apart. Display only.

const REBUILD_INTERVAL := 0.1
const RAYS := 21
## Metres between samples along each ray.
const STEP := 1.0
const LIFT := 0.12
const GROUND_RAY_UP := 4.0
const GROUND_RAY_LENGTH := 30.0
const NEAR_COLOR := Color(0.9, 0.1, 0.1, 0.4)
const FAR_COLOR := Color(1.0, 0.85, 0.1, 0.3)

## The guard shown, or null.
var guard: Guard
## Ground points of the last rebuild: the guard's position, then one point per ray.
var near_polygon := PackedVector3Array()
var far_polygon := PackedVector3Array()
## Patches of ground drawn in each zone at the last rebuild.
var near_quads := 0
var far_quads := 0

var _near_mesh := MeshInstance3D.new()
var _far_mesh := MeshInstance3D.new()
var _since_rebuild := 0.0


func _ready() -> void:
	visible = false
	for m in [_far_mesh, _near_mesh]:
		m.material_override = _material(NEAR_COLOR if m == _near_mesh else FAR_COLOR)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)


func show_for(g: Guard) -> void:
	if guard != null and is_instance_valid(guard) and guard.died.is_connected(_on_guard_died):
		guard.died.disconnect(_on_guard_died)
	guard = g
	if g == null or not is_instance_valid(g):
		hide_overlay()
		return
	g.died.connect(_on_guard_died)
	visible = true
	rebuild()


func hide_overlay() -> void:
	if guard != null and is_instance_valid(guard) and guard.died.is_connected(_on_guard_died):
		guard.died.disconnect(_on_guard_died)
	guard = null
	visible = false
	near_polygon = PackedVector3Array()
	far_polygon = PackedVector3Array()
	near_quads = 0
	far_quads = 0
	if _near_mesh != null:
		_near_mesh.mesh = null
		_far_mesh.mesh = null


func _process(delta: float) -> void:
	if not visible:
		return
	# A freed guard compares equal to null, so test visibility, not the reference.
	if not is_instance_valid(guard) or not guard.alive:
		hide_overlay()
		return
	_since_rebuild += delta
	if _since_rebuild >= REBUILD_INTERVAL:
		rebuild()


## Recomputes both zones from the guard's current position, facing and far range. Red is drawn
## where someone crawling would be seen, out to the near range; yellow where someone standing
## would be, from there to the far range. Ground the guard cannot see is left bare, so a dip, a
## wall or the foot of a bank shows as a gap.
func rebuild() -> void:
	_since_rebuild = 0.0
	if guard == null or not is_instance_valid(guard) or not guard.is_inside_tree():
		hide_overlay()
		return
	var vision := guard.vision
	near_polygon = Perception.polygon(guard, vision.near_range, RAYS, vision)
	far_polygon = Perception.polygon(guard, guard.current_far_range(), RAYS, vision)
	var near := Perception.ground_samples(guard, vision.near_range, RAYS, STEP,
			vision.target_height_crawling, _ground_under, vision)
	var far := Perception.ground_samples(guard, guard.current_far_range(), RAYS, STEP,
			vision.target_height_standing, _ground_under, vision, vision.near_range)
	var near_verts := _quads(near)
	var far_verts := _quads(far)
	near_quads = near_verts.size() / 6
	far_quads = far_verts.size() / 6
	_near_mesh.mesh = _mesh(near_verts)
	_far_mesh.mesh = _mesh(far_verts)
	# The meshes are in world coordinates; this node stays at the origin.
	global_transform = Transform3D.IDENTITY


## Whatever a unit would stand on at this point near the guard: the land, or the bridge deck.
func _ground_under(x: float, z: float) -> float:
	var top := guard.global_position.y + GROUND_RAY_UP
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, top - GROUND_RAY_LENGTH, z),
			Perception.WORLD_MASK)
	var hit := guard.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"].y if hit.has("position") else guard.global_position.y


func _on_guard_died(_unit: Unit) -> void:
	hide_overlay()


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


static func _lifted(p: Vector3) -> Vector3:
	return p + Vector3.UP * LIFT


## Two triangles for every patch of ground between neighbouring samples whose four corners are
## all in sight, lifted a little off the ground.
static func _quads(samples: Dictionary) -> PackedVector3Array:
	var points: Array = samples["points"]
	var visible: Array = samples["visible"]
	var verts := PackedVector3Array()
	for i in points.size() - 1:
		var a: PackedVector3Array = points[i]
		var b: PackedVector3Array = points[i + 1]
		var a_seen: PackedByteArray = visible[i]
		var b_seen: PackedByteArray = visible[i + 1]
		for j in a.size() - 1:
			if a_seen[j] + a_seen[j + 1] + b_seen[j] + b_seen[j + 1] < 4:
				continue
			verts.append_array([_lifted(a[j]), _lifted(a[j + 1]), _lifted(b[j + 1]),
					_lifted(a[j]), _lifted(b[j + 1]), _lifted(b[j])])
	return verts


static func _mesh(verts: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
