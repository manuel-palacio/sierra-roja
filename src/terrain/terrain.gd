class_name Terrain
extends StaticBody3D
## The ground of a mission: draws a HeightField as a textured mesh and gives it collision made of
## the same triangles, so sight rays, mouse picking and the navmesh bake all meet the land the
## player sees. Grass, dry earth, road and ballast are textures blended by weights at each vertex;
## rock shows on steep faces. The mesh is cut into chunks so lamps (eight lights per mesh in the
## Compatibility renderer) and culling work per chunk.

## Quads per chunk side.
const CHUNK := 32
## Collision covers the playable bounds plus this many metres.
const COLLISION_MARGIN := 6.0
const SHADER := preload("res://assets/shaders/terrain.gdshader")
const TEXTURES := {
	"grass": preload("res://assets/textures/grass.jpg"),
	"earth": preload("res://assets/textures/earth.jpg"),
	"road": preload("res://assets/textures/road.jpg"),
	"ballast": preload("res://assets/textures/ballast.jpg"),
	"rock": preload("res://assets/textures/rock.jpg"),
	"grass_normal": preload("res://assets/textures/grass_normal.jpg"),
	"earth_normal": preload("res://assets/textures/earth_normal.jpg"),
	"road_normal": preload("res://assets/textures/road_normal.jpg"),
	"rock_normal": preload("res://assets/textures/rock_normal.jpg"),
}
## What the land dissolves into past the edge of the map: the morning haze. main.tscn's
## background is the same colour.
const MIST := Color(0.56, 0.60, 0.64)
## Grass gives way to dry earth where this noise is high.
const EARTH_PERIOD := 17.0
const EARTH_FROM := 0.12
const EARTH_FULL := 0.42
## Land beyond the playable bounds fades into the mist over this share of the skirt, so the map
## has no visible end.
const FADE_SHARE := 0.75
## Metres of ground per pixel of the baked shade.
const SHADE_CELL := 0.5

@export var spec: TerrainSpec
var field: HeightField

var _material: ShaderMaterial
var _shade: Image
var _earth: FastNoiseLite


func _ready() -> void:
	build()


func height_at(x: float, z: float) -> float:
	return field.height_at(x, z) if field != null else 0.0


## Builds the field, the mesh chunks and the collision. Safe to call again.
func build() -> void:
	collision_layer = Unit.LAYER_WORLD
	collision_mask = 0
	for child in get_children():
		remove_child(child)
		child.free()
	if spec == null:
		return
	field = TerrainGenerator.build(spec)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	for key in TEXTURES:
		_material.set_shader_parameter(key, TEXTURES[key])
	var b := spec.bounds
	_material.set_shader_parameter("bounds", Vector4(b.position.x, b.position.y, b.end.x, b.end.y))
	_material.set_shader_parameter("fade_distance", maxf(spec.skirt * FADE_SHARE, 0.001))
	_material.set_shader_parameter("mist", MIST)
	bake_shade([])
	_earth = FastNoiseLite.new()
	_earth.seed = spec.seed + 1
	_earth.frequency = 1.0 / EARTH_PERIOD
	for row in range(0, field.rows - 1, CHUNK):
		for col in range(0, field.cols - 1, CHUNK):
			add_child(_chunk(col, row))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces(spec.bounds.grow(COLLISION_MARGIN)))
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)


## The triangles of every quad that lies inside the area, in world space (the terrain sits at the
## origin). Used for collision and as the navmesh bake's source.
func faces(area: Rect2) -> PackedVector3Array:
	var out := PackedVector3Array()
	if field == null:
		return out
	var eps := field.cell * 0.001
	var c0 := maxi(int(ceilf((area.position.x - field.origin.x) / field.cell - eps)), 0)
	var r0 := maxi(int(ceilf((area.position.y - field.origin.y) / field.cell - eps)), 0)
	var c1 := mini(int(floorf((area.end.x - field.origin.x) / field.cell + eps)), field.cols - 1)
	var r1 := mini(int(floorf((area.end.y - field.origin.y) / field.cell + eps)), field.rows - 1)
	if c1 <= c0 or r1 <= r0:
		return out
	out.resize((c1 - c0) * (r1 - r0) * 6)
	var i := 0
	for r in range(r0, r1):
		for c in range(c0, c1):
			var v00 := field.vertex(c, r)
			var v11 := field.vertex(c + 1, r + 1)
			out[i] = v00
			out[i + 1] = field.vertex(c + 1, r)
			out[i + 2] = v11
			out[i + 3] = v00
			out[i + 4] = v11
			out[i + 5] = field.vertex(c, r + 1)
			i += 6
	return out


func _chunk(col0: int, row0: int) -> MeshInstance3D:
	var col1 := mini(col0 + CHUNK, field.cols - 1)
	var row1 := mini(row0 + CHUNK, field.rows - 1)
	var wide := col1 - col0 + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for r in range(row0, row1 + 1):
		for c in range(col0, col1 + 1):
			verts.append(field.vertex(c, r))
			normals.append(_normal(c, r))
			colors.append(_weights(c, r))
	var indices := PackedInt32Array()
	for r in row1 - row0:
		for c in col1 - col0:
			var i := r * wide + c
			# The same split as HeightField.height_at and faces(): (c, r) to (c + 1, r + 1).
			indices.append_array([i, i + 1, i + wide + 1, i, i + wide + 1, i + wide])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	var instance := MeshInstance3D.new()
	instance.name = "Chunk_%d_%d" % [col0 / CHUNK, row0 / CHUNK]
	instance.mesh = mesh
	return instance


## The land's normal at a vertex, from its neighbours' heights.
func _normal(c: int, r: int) -> Vector3:
	var dx := field.get_h(c + 1, r) - field.get_h(c - 1, r)
	var dz := field.get_h(c, r + 1) - field.get_h(c, r - 1)
	return Vector3(-dx, 2.0 * field.cell, -dz).normalized()


## How much of each ground texture a vertex shows, as (grass, earth, road, ballast). Rock is the
## absence of all four. Untagged land is grass with patches of dry earth.
func _weights(c: int, r: int) -> Color:
	match field.get_surface(c, r):
		HeightField.Surface.EARTH:
			return Color(0, 1, 0, 0)
		HeightField.Surface.ROAD:
			return Color(0, 0, 1, 0)
		HeightField.Surface.BALLAST:
			return Color(0, 0, 0, 1)
		HeightField.Surface.ROCK:
			return Color(0, 0, 0, 0)
	var p := field.vertex(c, r)
	var dry := smoothstep(EARTH_FROM, EARTH_FULL, _earth.get_noise_2d(p.x, p.z))
	return Color(1.0 - dry, dry, 0, 0)


## Bakes the soft shade that things standing on the land throw round their feet, which is what
## makes them sit on the ground instead of on top of it. Each caster is a dictionary:
## "at" (Vector2, ground plane), "half" (Vector2, half its footprint along its own x and z),
## "turn" (radians about y), "reach" (metres the shade spreads beyond the footprint) and
## "strength" (0 to 1, how dark at the footprint). Calling it again replaces the last bake.
func bake_shade(casters: Array) -> void:
	var b := spec.bounds
	var wide := maxi(int(ceilf(b.size.x / SHADE_CELL)), 1)
	var deep := maxi(int(ceilf(b.size.y / SHADE_CELL)), 1)
	var dark := PackedFloat32Array()
	dark.resize(wide * deep)
	for caster: Dictionary in casters:
		var at: Vector2 = caster["at"]
		var half: Vector2 = caster["half"]
		var reach: float = caster["reach"]
		var strength: float = caster["strength"]
		var turn: float = caster.get("turn", 0.0)
		var span := half.length() + reach
		var x0 := maxi(int(floorf((at.x - span - b.position.x) / SHADE_CELL)), 0)
		var x1 := mini(int(ceilf((at.x + span - b.position.x) / SHADE_CELL)), wide - 1)
		var z0 := maxi(int(floorf((at.y - span - b.position.y) / SHADE_CELL)), 0)
		var z1 := mini(int(ceilf((at.y + span - b.position.y) / SHADE_CELL)), deep - 1)
		for pz in range(z0, z1 + 1):
			for px in range(x0, x1 + 1):
				var p := Vector2(b.position.x + (px + 0.5) * SHADE_CELL, b.position.y + (pz + 0.5) * SHADE_CELL)
				var local := (p - at).rotated(turn)
				var outside := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0)).length()
				var amount := strength * (1.0 - smoothstep(0.0, reach, outside))
				var i := pz * wide + px
				# Shades overlap by taking the darker, with a little of the other added.
				dark[i] = minf(maxf(dark[i], amount) + minf(dark[i], amount) * 0.35, 0.85)
	_shade = Image.create(wide, deep, false, Image.FORMAT_L8)
	for pz in deep:
		for px in wide:
			var light := 1.0 - dark[pz * wide + px]
			_shade.set_pixel(px, pz, Color(light, light, light))
	if _material != null:
		_material.set_shader_parameter("shade", ImageTexture.create_from_image(_shade))


## Changes what the land dissolves into past the edge of the map, and how dark cloud shadows are
## (none at night).
func set_sky(mist: Color, cloud_shade: float) -> void:
	if _material != null:
		_material.set_shader_parameter("mist", mist)
		_material.set_shader_parameter("cloud_shade", cloud_shade)


## How light the baked shade leaves a point of the ground: 1 in the open, less beside things.
func shade_at(x: float, z: float) -> float:
	if _shade == null:
		return 1.0
	var b := spec.bounds
	var px := clampi(int((x - b.position.x) / SHADE_CELL), 0, _shade.get_width() - 1)
	var pz := clampi(int((z - b.position.y) / SHADE_CELL), 0, _shade.get_height() - 1)
	return _shade.get_pixel(px, pz).r


## 0 inside the bounds, rising to 1 out across the skirt.
func edge_fade(x: float, z: float) -> float:
	var b := spec.bounds
	var outside := Vector2(maxf(maxf(b.position.x - x, x - b.end.x), 0.0),
			maxf(maxf(b.position.y - z, z - b.end.y), 0.0)).length()
	return smoothstep(0.0, maxf(spec.skirt * FADE_SHARE, 0.001), outside)
