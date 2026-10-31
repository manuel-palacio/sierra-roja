class_name VisionOverlay
extends Node3D
## Draws one guard's vision on the ground: the near zone in red, the far zone (a ring around it)
## in yellow. Unlit and translucent so it shows in the Compatibility renderer, a little above
## the ground. Rebuilt at most REBUILD_INTERVAL seconds apart. Display only.

const REBUILD_INTERVAL := 0.1
const RAYS := 24
const LIFT := 0.08
const NEAR_COLOR := Color(0.9, 0.1, 0.1, 0.4)
const FAR_COLOR := Color(1.0, 0.85, 0.1, 0.3)

## The guard shown, or null.
var guard: Guard
## Ground points of the last rebuild: the guard's position, then one point per ray.
var near_polygon := PackedVector3Array()
var far_polygon := PackedVector3Array()

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


## Recomputes both zones from the guard's current position, facing and far range.
func rebuild() -> void:
	_since_rebuild = 0.0
	if guard == null or not is_instance_valid(guard) or not guard.is_inside_tree():
		hide_overlay()
		return
	near_polygon = Perception.polygon(guard, guard.vision.near_range, RAYS, guard.vision)
	far_polygon = Perception.polygon(guard, guard.current_far_range(), RAYS, guard.vision)
	_near_mesh.mesh = _fan(near_polygon)
	_far_mesh.mesh = _ring(near_polygon, far_polygon)
	# The meshes are in world coordinates; this node stays at the origin.
	global_transform = Transform3D.IDENTITY


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


## Triangle fan from poly[0] across the rest.
static func _fan(poly: PackedVector3Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in range(1, poly.size() - 1):
		verts.append(_lifted(poly[0]))
		verts.append(_lifted(poly[i]))
		verts.append(_lifted(poly[i + 1]))
	return _mesh(verts)


## Strip between two polygons with the same ray angles (inner[i] -> outer[i]).
static func _ring(inner: PackedVector3Array, outer: PackedVector3Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in range(1, mini(inner.size(), outer.size()) - 1):
		verts.append_array([_lifted(inner[i]), _lifted(outer[i]), _lifted(outer[i + 1]),
				_lifted(inner[i]), _lifted(outer[i + 1]), _lifted(inner[i + 1])])
	return _mesh(verts)


static func _mesh(verts: PackedVector3Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
