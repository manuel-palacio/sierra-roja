class_name PropScatter
extends Node3D
## Scatters copies of kit models over an area of the land: trees, rocks, scrub. Placement is
## seeded, so the same settings always give the same map. Copies are drawn as MultiMeshes (one per
## mesh in each model). With a blocker size each copy also gets a box on the world layer, which
## stops feet and eyes and which the navmesh bake cuts out; for that the node must be under Nav/.
## The node stays at the origin; Mission calls build() before the bake.

## Tries per wanted copy before giving up on finding room.
const ATTEMPTS := 12
## The kit's materials by name, recoloured from its pastel palette to a dry Spanish hillside.
## A material not listed keeps its own colour.
const PALETTE := {
	"leafsDark": Color(0.13, 0.26, 0.15),
	"grass": Color(0.37, 0.40, 0.21),
	"dirt": Color(0.46, 0.42, 0.37),
	"_defaultMat": Color(0.52, 0.48, 0.43),
	"stone": Color(0.50, 0.47, 0.43),
	"woodBarkDark": Color(0.27, 0.19, 0.13),
	"woodBark": Color(0.38, 0.27, 0.18),
	"woodInner": Color(0.62, 0.50, 0.36),
	"wood": Color(0.45, 0.33, 0.20),
	"woodDark": Color(0.33, 0.24, 0.15),
}

@export var models: Array[PackedScene] = []
## Polygon on the ground plane (x, z).
@export var area := PackedVector2Array()
@export var count := 50
@export var seed := 1
## Least distance between two copies of this scatter.
@export var min_spacing := 2.0
@export var max_slope_deg := 30.0
@export var scale_range := Vector2(0.8, 1.3)
## Least distance to a road, path, yard or the track, a spawn, a patrol route, an objective, a wall or a building.
@export var keep_clear := 2.5
## More places to keep clear of: trails and hiding spots the map wants open.
@export var clear_points := PackedVector2Array()
## Non-zero: every copy blocks with a box this size, standing on the ground.
@export var blocker_size := Vector3.ZERO

static var _recoloured: Dictionary = {}

var _transforms: Array[Transform3D] = []
var _model_of: PackedInt32Array = []


func transforms() -> Array[Transform3D]:
	return _transforms


func build(mission: Mission) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_transforms.clear()
	_model_of.clear()
	var land := mission.terrain()
	if land == null or models.is_empty() or area.size() < 3:
		return
	_place(mission, land)
	for m in models.size():
		_add_multimeshes(m)
	if blocker_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.name = "Blockers"
		body.collision_layer = Unit.LAYER_WORLD
		body.collision_mask = 0
		add_child(body)
		for t in _transforms:
			var shape := BoxShape3D.new()
			shape.size = blocker_size
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = t.origin + Vector3.UP * (blocker_size.y / 2.0 - 0.3)
			body.add_child(collision)


func _place(mission: Mission, land: Terrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var box := Rect2(area[0], Vector2.ZERO)
	for p in area:
		box = box.expand(p)
	var avoid := _points_to_avoid(mission)
	var boxes := _boxes_to_avoid(mission)
	for i in count * ATTEMPTS:
		if _transforms.size() >= count:
			break
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		var turn := rng.randf_range(0.0, TAU)
		var size := rng.randf_range(scale_range.x, scale_range.y)
		var model := rng.randi_range(0, models.size() - 1)
		if not _fits(p, land, avoid, boxes):
			continue
		var at := Vector3(p.x, land.height_at(p.x, p.y), p.y)
		_transforms.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), at))
		_model_of.append(model)


func _fits(p: Vector2, land: Terrain, avoid: Array[PackedVector2Array], boxes: Array) -> bool:
	if not Geometry2D.is_point_in_polygon(p, area):
		return false
	if land.field.slope_deg_at(p.x, p.y) >= max_slope_deg:
		return false
	for t in _transforms:
		if Vector2(t.origin.x - p.x, t.origin.z - p.y).length() < min_spacing:
			return false
	# Roads, paths, yards and the track: any vertex the land's features tagged, within reach.
	var field := land.field
	var reach := int(ceilf(keep_clear / field.cell))
	var c0 := int(roundf((p.x - field.origin.x) / field.cell))
	var r0 := int(roundf((p.y - field.origin.y) / field.cell))
	for r in range(r0 - reach, r0 + reach + 1):
		for c in range(c0 - reach, c0 + reach + 1):
			var surface := field.get_surface(c, r)
			if surface != HeightField.Surface.GRASS and surface != HeightField.Surface.ROCK:
				var v := field.vertex(c, r)
				if Vector2(v.x - p.x, v.z - p.y).length() < keep_clear:
					return false
	for line in avoid:
		for i in maxi(line.size() - 1, 1):
			var a := line[i]
			var b := line[mini(i + 1, line.size() - 1)]
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < keep_clear:
				return false
	for entry in boxes:
		var local: Vector3 = (entry[0] as Transform3D) * Vector3(p.x, 0.0, p.y)
		var half: Vector3 = entry[1]
		if Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.z, 0.0)).length() < keep_clear:
			return false
	return true


## Spawns and objectives as single points, patrol routes as closed lines.
func _points_to_avoid(mission: Mission) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var single: Array[Node3D] = []
	single.append_array(mission.specialist_spawns())
	single.append_array(mission.guard_spawns())
	if mission.bridge_target():
		single.append(mission.bridge_target())
	if mission.extraction():
		single.append(mission.extraction())
	for node in single:
		out.append(PackedVector2Array([Vector2(node.global_position.x, node.global_position.z)]))
	for p in clear_points:
		out.append(PackedVector2Array([p]))
	for route in mission.patrol_routes():
		if route.curve == null or route.curve.point_count == 0:
			continue
		var line := PackedVector2Array()
		for i in route.curve.point_count + 1:
			var q := route.to_global(route.curve.get_point_position(i % route.curve.point_count))
			line.append(Vector2(q.x, q.z))
		out.append(line)
	return out


## Every wall and building box already standing: [world-to-box transform, half size].
func _boxes_to_avoid(mission: Mission) -> Array:
	var out := []
	for node in mission.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var owner_body := collision.get_parent()
		if collision.shape is BoxShape3D and (owner_body is StoneWall or owner_body is Building):
			out.append([collision.global_transform.affine_inverse(), (collision.shape as BoxShape3D).size / 2.0])
	return out


func _add_multimeshes(model: int) -> void:
	var places: Array[Transform3D] = []
	for i in _transforms.size():
		if _model_of[i] == model:
			places.append(_transforms[i])
	if places.is_empty():
		return
	var scene := models[model].instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false) + ([scene] if scene is MeshInstance3D else []):
		var source := node as MeshInstance3D
		# The mesh's own placement inside the model.
		var inner := Transform3D.IDENTITY
		var walker: Node = source
		while walker != null and walker is Node3D:
			inner = (walker as Node3D).transform * inner
			if walker == scene:
				break
			walker = walker.get_parent()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _in_palette(source.mesh)
		multi.instance_count = places.size()
		for i in places.size():
			multi.set_instance_transform(i, places[i] * inner)
		var holder := MultiMeshInstance3D.new()
		holder.multimesh = multi
		add_child(holder)
	scene.free()


## The mesh with each palette material swapped for its recoloured twin.
static func _in_palette(mesh: Mesh) -> Mesh:
	var copy: Mesh = null
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as BaseMaterial3D
		if material == null or not PALETTE.has(material.resource_name):
			continue
		if not _recoloured.has(material.resource_name):
			var twin := material.duplicate() as BaseMaterial3D
			twin.albedo_color = PALETTE[material.resource_name]
			twin.roughness = 1.0
			twin.metallic_specular = 0.1
			_recoloured[material.resource_name] = twin
		if copy == null:
			copy = mesh.duplicate()
		copy.surface_set_material(i, _recoloured[material.resource_name])
	return copy if copy != null else mesh
