class_name TerrainFeature
extends Resource
## One authored shape in a landscape: a hill, a pad, a gorge, an embankment, a road.

enum Kind {
	MOUND,  ## Radial, around points[0].
	PATH,   ## Along the polyline in points.
}
enum Mode {
	ADD,  ## Raises (or, with a negative height, lowers) the land by `height`.
	SET,  ## Blends the land toward the absolute `height`.
}

@export var kind := Kind.MOUND
@export var mode := Mode.ADD
## Ground-plane points (x, z).
@export var points := PackedVector2Array()
## Radius (MOUND) or half-width (PATH) at full strength.
@export var width := 1.0
## Metres over which the strength eases from 1 to 0 outside the width.
@export var falloff := 1.0
@export var height := 0.0
## PATH with SET only: the height at the last point, for a ramp. NAN means the same as `height`.
@export var end_height := NAN
## HeightField.Surface for the full-strength zone, or -1 to leave the surface alone.
@export var surface := -1
