class_name Terrain
extends StaticBody3D
## The ground of a mission: draws a HeightField as a flat-shaded, vertex-coloured mesh and gives it
## collision made of the same triangles, so sight rays, mouse picking and the navmesh bake all meet
## the land the player sees. The mesh is cut into chunks so lamps (eight lights per mesh in the
## Compatibility renderer) and culling work per chunk.

## Quads per chunk side.
const CHUNK := 32
## Faces steeper than this are drawn as rock.
const ROCK_SLOPE_DEG := 38.0
## Collision covers the playable bounds plus this many metres.
const COLLISION_MARGIN := 6.0
const COLORS := {
	HeightField.Surface.GRASS: Color(0.30, 0.37, 0.18),
	HeightField.Surface.EARTH: Color(0.44, 0.38, 0.24),
	HeightField.Surface.ROAD: Color(0.55, 0.47, 0.33),
	HeightField.Surface.BALLAST: Color(0.43, 0.41, 0.40),
	HeightField.Surface.ROCK: Color(0.42, 0.39, 0.36),
}
## Each face is lighter or darker by up to this share, so the facets read.
const SHADE_JITTER := 0.07
## Grass gives way to bare earth where this noise is high.
const EARTH_PERIOD := 17.0
const EARTH_THRESHOLD := 0.28

@export var spec: TerrainSpec
var field: HeightField

var _material: StandardMaterial3D


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
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_material.metallic_specular = 0.0
	var earth := FastNoiseLite.new()
	earth.seed = spec.seed + 1
	earth.frequency = 1.0 / EARTH_PERIOD
	for row in range(0, field.rows - 1, CHUNK):
		for col in range(0, field.cols - 1, CHUNK):
			add_child(_chunk(col, row, earth))
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


func _chunk(col0: int, row0: int, earth: FastNoiseLite) -> MeshInstance3D:
	var col1 := mini(col0 + CHUNK, field.cols - 1)
	var row1 := mini(row0 + CHUNK, field.rows - 1)
	var count := (col1 - col0) * (row1 - row0) * 6
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(count)
	normals.resize(count)
	colors.resize(count)
	var i := 0
	for r in range(row0, row1):
		for c in range(col0, col1):
			var v00 := field.vertex(c, r)
			var v10 := field.vertex(c + 1, r)
			var v11 := field.vertex(c + 1, r + 1)
			var v01 := field.vertex(c, r + 1)
			var base := _surface_of(c, r, earth)
			for tri in 2:
				var a := v00
				var b := v10 if tri == 0 else v11
				var d := v11 if tri == 0 else v01
				var normal := (d - a).cross(b - a).normalized()
				var color := _shade(base, normal, c, r, tri)
				for v in [a, b, d]:
					verts[i] = v
					normals[i] = normal
					colors[i] = color
					i += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	var instance := MeshInstance3D.new()
	instance.name = "Chunk_%d_%d" % [col0 / CHUNK, row0 / CHUNK]
	instance.mesh = mesh
	return instance


## A quad's surface: what the generator tagged, else earth in patches over the grass.
func _surface_of(c: int, r: int, earth: FastNoiseLite) -> HeightField.Surface:
	var tagged := field.get_surface(c, r)
	if tagged != HeightField.Surface.GRASS:
		return tagged
	var p := field.vertex(c, r)
	return HeightField.Surface.EARTH if earth.get_noise_2d(p.x, p.z) > EARTH_THRESHOLD \
			else HeightField.Surface.GRASS


func _shade(surface: HeightField.Surface, normal: Vector3, c: int, r: int, tri: int) -> Color:
	var steep := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))) > ROCK_SLOPE_DEG
	var color: Color = COLORS[HeightField.Surface.ROCK if steep else surface]
	var jitter := float(hash(Vector3i(c, r, tri)) % 1000) / 999.0 * 2.0 - 1.0
	return color.lightened(jitter * SHADE_JITTER) if jitter > 0.0 else color.darkened(-jitter * SHADE_JITTER)
