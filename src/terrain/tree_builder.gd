class_name TreeBuilder
extends RefCounted
## Makes trees and bushes: a tapered, barked trunk under a canopy of leaf sprites hung in a ball
## (broadleaves) or in drooping tiers (pines), round a dark core so the tree is not seen through.
## The sprites' normals point out from the middle of the canopy, so the whole crown shades as one
## rounded mass, lit on the sunny side. A few seeded variants of each kind are made once and
## shared; PropScatter draws them as MultiMeshes.

const VARIANTS := 3
const SNOW_LEAF := preload("res://assets/shaders/snow_leaf.gdshader")
const LEAVES := {
	&"broad": preload("res://assets/textures/leaves_broad.png"),
	&"pine": preload("res://assets/textures/leaves_pine.png"),
}
## Kind -> its shape. Heights and radii in metres. "tint" is laid over the leaf sprite.
const KINDS := {
	&"pine": { "leaf": &"pine", "height": 8.5, "trunk": 0.20, "crown": 2.3, "crown_from": 1.9, "tint": Color(0.52, 0.64, 0.52) },
	&"oak": { "leaf": &"broad", "height": 6.5, "trunk": 0.30, "crown": 2.7, "crown_from": 2.3, "tint": Color(0.56, 0.64, 0.44) },
	&"olive": { "leaf": &"broad", "height": 4.2, "trunk": 0.24, "crown": 2.0, "crown_from": 1.5, "tint": Color(0.56, 0.62, 0.52) },
	&"sapling": { "leaf": &"broad", "height": 2.6, "trunk": 0.08, "crown": 0.9, "crown_from": 1.1, "tint": Color(0.62, 0.70, 0.46) },
	&"bush": { "leaf": &"broad", "height": 1.0, "trunk": 0.0, "crown": 0.85, "crown_from": 0.1, "tint": Color(0.56, 0.63, 0.42) },
	# Winter. A pine under snow; and trees with no leaves, which are a trunk and bare branches:
	# "bark" is the trunk's flat colour, "tint" the branches'.
	&"snow_pine": { "leaf": &"pine", "height": 8.5, "trunk": 0.20, "crown": 2.3, "crown_from": 1.9, "tint": Color(0.52, 0.64, 0.52), "snow": 0.75 },
	&"birch": { "leaf": &"none", "height": 7.0, "trunk": 0.14, "crown": 1.9, "crown_from": 2.6, "tint": Color(0.24, 0.20, 0.18), "bark": Color(0.90, 0.90, 0.87) },
	&"bare_bush": { "leaf": &"none", "height": 1.0, "trunk": 0.0, "crown": 0.8, "crown_from": 0.0, "tint": Color(0.30, 0.24, 0.19) },
}

static var _made: Dictionary = {}
static var _foliage: Dictionary = {}


## The meshes of a kind of tree, VARIANTS of them, or none for a kind there is not.
static func variants(kind: StringName) -> Array[Mesh]:
	var out: Array[Mesh] = []
	if not KINDS.has(kind):
		return out
	if not _made.has(kind):
		var meshes: Array[Mesh] = []
		for i in VARIANTS:
			meshes.append(_build(kind, i))
		_made[kind] = meshes
	out.assign(_made[kind])
	return out


static func _build(kind: StringName, variant: int) -> ArrayMesh:
	var shape: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([kind, variant])
	var height: float = shape["height"] * rng.randf_range(0.9, 1.1)
	var crown: float = shape["crown"] * rng.randf_range(0.9, 1.1)
	var from: float = shape["crown_from"]
	var mesh := ArrayMesh.new()
	if shape["leaf"] == &"none":
		return _build_bare(shape, rng, height, crown)
	if float(shape["trunk"]) > 0.0:
		var trunk := SurfaceTool.new()
		trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
		_trunk(trunk, float(shape["trunk"]), height * (0.92 if shape["leaf"] == &"pine" else 0.7))
		trunk.generate_normals()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.commit_to_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, Surfaces.material(&"bark", Color(0.80, 0.72, 0.66)))
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	if shape["leaf"] == &"pine":
		_pine_crown(leaves, core, rng, from, height, crown)
	else:
		_ball_crown(leaves, core, rng, Vector3(0, maxf(height - crown * 0.8, from + crown * 0.5), 0), crown)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, core.commit_to_arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, _core_material(shape["tint"]))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, leaves.commit_to_arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, _snow_leaf_material(shape["leaf"], shape["tint"], shape["snow"])
			if shape.has("snow") else _leaf_material(shape["leaf"], shape["tint"]))
	return mesh


## A tree with no leaves: a trunk in a flat colour, if it has one, and bare branches going up and
## out from it (from the ground, for a bush).
static func _build_bare(shape: Dictionary, rng: RandomNumberGenerator, height: float, crown: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var from: float = shape["crown_from"]
	if float(shape["trunk"]) > 0.0:
		var trunk := SurfaceTool.new()
		trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
		_trunk(trunk, float(shape["trunk"]), height)
		trunk.generate_normals()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.commit_to_arrays())
		mesh.surface_set_material(0, _flat_material(shape["bark"]))
	var twigs := SurfaceTool.new()
	twigs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 9 if float(shape["trunk"]) > 0.0 else 7
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var out := Vector3(cos(a), 0, sin(a))
		var start := Vector3(0, lerpf(from, height * 0.9, float(i) / count), 0)
		var reach := crown * rng.randf_range(0.6, 1.0) * (1.0 - 0.5 * float(i) / count)
		var end := start + out * reach + Vector3.UP * reach * rng.randf_range(0.7, 1.2)
		_stick(twigs, start, end, maxf(float(shape["trunk"]) * 0.32, 0.025))
		# A fork half way along.
		var side := out.rotated(Vector3.UP, rng.randf_range(0.6, 1.1) * (1.0 if i % 2 == 0 else -1.0))
		_stick(twigs, start.lerp(end, 0.5), start.lerp(end, 0.5) + side * reach * 0.5 + Vector3.UP * reach * 0.45, 0.02)
	twigs.generate_normals()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, twigs.commit_to_arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, _flat_material(shape["tint"]))
	return mesh


## A thin four-sided stick from one point to another, tapering.
static func _stick(st: SurfaceTool, from: Vector3, to: Vector3, radius: float) -> void:
	var along := (to - from).normalized()
	var u := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := along.cross(u)
	for i in 4:
		var a0: Vector3 = [u, v, -u, -v][i]
		var a1: Vector3 = [u, v, -u, -v][(i + 1) % 4]
		var b0 := from + a0 * radius
		var b1 := from + a1 * radius
		var t0 := to + a0 * radius * 0.4
		var t1 := to + a1 * radius * 0.4
		for p in [b0, t1, b1, b0, t0, t1]:
			st.add_vertex(p)


static func _flat_material(colour: Color) -> StandardMaterial3D:
	var key := [&"flat", colour]
	if not _foliage.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_foliage[key] = m
	return _foliage[key]


## A tapered eight-sided post from the ground up.
static func _trunk(st: SurfaceTool, radius: float, height: float) -> void:
	var sides := 8
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var b1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var t0 := Vector3(cos(a0), 0, sin(a0)) * radius * 0.45 + Vector3.UP * height
		var t1 := Vector3(cos(a1), 0, sin(a1)) * radius * 0.45 + Vector3.UP * height
		for v in [b0, t1, b1, b0, t0, t1]:
			st.add_vertex(v + Vector3.DOWN * 0.3)


## Leaf sprites all over a ball, each facing mostly outward, round a dark ball.
static func _ball_crown(leaves: SurfaceTool, core: SurfaceTool, rng: RandomNumberGenerator, centre: Vector3,
		radius: float) -> void:
	_blob(core, centre, Vector3(radius * 0.72, radius * 0.62, radius * 0.72))
	var cards := int(26 + radius * 22)
	for i in cards:
		var out := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.55, 1), rng.randf_range(-1, 1)).normalized()
		var at := centre + out * Vector3(radius, radius * 0.82, radius) * rng.randf_range(0.62, 1.0)
		var facing := (out + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		_card(leaves, at, facing, rng.randf_range(0, TAU), radius * rng.randf_range(0.55, 0.85), (at - centre + Vector3.UP * radius * 0.35).normalized())


## Tiers of boughs round the trunk, widest at the bottom, each hanging down and out.
static func _pine_crown(leaves: SurfaceTool, core: SurfaceTool, rng: RandomNumberGenerator, from: float,
		height: float, radius: float) -> void:
	_cone(core, from + 0.4, height * 0.97, radius * 0.5)
	var tiers := 8
	for tier in tiers:
		var t := float(tier) / (tiers - 1)
		var y := lerpf(from + 0.6, height, t)
		var reach := lerpf(radius, radius * 0.22, t)
		var boughs := 7 if t < 0.7 else 5
		for b in boughs:
			var a := TAU * (b + rng.randf_range(-0.25, 0.25)) / boughs + tier * 0.6
			var out := Vector3(cos(a), 0, sin(a))
			var at := Vector3(0, y, 0) + out * reach * 0.55 + Vector3.DOWN * reach * 0.28
			# The bough's sprite hangs with its top toward the trunk, tipped down and outward.
			var facing := (out * 0.45 + Vector3.UP).normalized()
			var turn := atan2(out.x, out.z)
			_card(leaves, at, facing, turn, reach * rng.randf_range(0.95, 1.25), (out + Vector3.UP * 0.9).normalized(), out)


## One square sprite: centred at a point, facing a direction, turned about it, with every corner
## given the same shading normal. With `top_toward`, its top edge lies toward the trunk.
static func _card(st: SurfaceTool, at: Vector3, facing: Vector3, turn: float, size: float, normal: Vector3,
		hang_out := Vector3.ZERO) -> void:
	var side: Vector3
	var up: Vector3
	if hang_out != Vector3.ZERO:
		up = (-hang_out + Vector3.UP * 0.55).normalized()
		side = up.cross(facing).normalized()
		up = facing.cross(side).normalized()
	else:
		var reference := Vector3.UP if absf(facing.y) < 0.95 else Vector3.RIGHT
		side = reference.cross(facing).normalized().rotated(facing, turn)
		up = facing.cross(side).normalized()
	var h := size / 2.0
	var corners := [at - side * h + up * h, at + side * h + up * h, at + side * h - up * h, at - side * h - up * h]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])


## A squashed low ball of flat colour, the shadowed inside of a crown.
static func _blob(st: SurfaceTool, centre: Vector3, radii: Vector3) -> void:
	var rings := 4
	var sides := 8
	for r in rings:
		for s in sides:
			var quad: Array[Vector3] = []
			for corner in [[r, s], [r, s + 1], [r + 1, s + 1], [r + 1, s]]:
				var lat := PI * float(corner[0]) / rings
				var lon := TAU * float(corner[1]) / sides
				quad.append(Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon)))
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_normal(quad[i])
				st.add_vertex(centre + quad[i] * radii)


static func _cone(st: SurfaceTool, from: float, to: float, radius: float) -> void:
	var sides := 8
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var b0 := Vector3(cos(a0) * radius, from, sin(a0) * radius)
		var b1 := Vector3(cos(a1) * radius, from, sin(a1) * radius)
		var tip := Vector3(0, to, 0)
		for v in [b0, tip, b1]:
			st.set_normal((Vector3(v.x, radius * 0.4, v.z)).normalized())
			st.add_vertex(v)


static func _leaf_material(leaf: StringName, tint: Color) -> StandardMaterial3D:
	var key := [leaf, tint]
	if not _foliage.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = LEAVES[leaf]
		m.albedo_color = tint
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.metallic_specular = 0.05
		_foliage[key] = m
	return _foliage[key]


## The same sprites with snow lying on them.
static func _snow_leaf_material(leaf: StringName, tint: Color, snow: float) -> ShaderMaterial:
	var key := [leaf, tint, snow]
	if not _foliage.has(key):
		var m := ShaderMaterial.new()
		m.shader = SNOW_LEAF
		m.set_shader_parameter("leaf", LEAVES[leaf])
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("snow_tint", Terrain.SNOW)
		m.set_shader_parameter("snow", snow)
		_foliage[key] = m
	return _foliage[key]


static func _core_material(tint: Color) -> StandardMaterial3D:
	var key := [&"core", tint]
	if not _foliage.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.10, 0.17, 0.08) * Color(tint.r, tint.g, tint.b)
		m.roughness = 1.0
		_foliage[key] = m
	return _foliage[key]
