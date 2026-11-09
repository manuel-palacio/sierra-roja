class_name HeightField
extends RefCounted
## A grid of ground heights over a rectangle of the map, with a surface tag per vertex.
## Each quad is split along the diagonal from (col, row) to (col + 1, row + 1), and sampling uses
## the same split, so height_at is exactly the surface Terrain draws and collides with.

enum Surface { GRASS, EARTH, ROAD, BALLAST, ROCK }

## Ground-plane position (x, z) of vertex (0, 0).
var origin: Vector2
## Metres between neighbouring vertices.
var cell: float
## Vertices along x and along z.
var cols: int
var rows: int

var _heights := PackedFloat32Array()
var _surfaces := PackedByteArray()


func _init(p_origin: Vector2, p_cell: float, p_cols: int, p_rows: int) -> void:
	origin = p_origin
	cell = p_cell
	cols = maxi(p_cols, 2)
	rows = maxi(p_rows, 2)
	_heights.resize(cols * rows)
	_surfaces.resize(cols * rows)


func rect() -> Rect2:
	return Rect2(origin, Vector2(cols - 1, rows - 1) * cell)


func get_h(col: int, row: int) -> float:
	return _heights[_index(col, row)]


func set_h(col: int, row: int, h: float) -> void:
	_heights[_index(col, row)] = h


func get_surface(col: int, row: int) -> Surface:
	return _surfaces[_index(col, row)] as Surface


func set_surface(col: int, row: int, s: Surface) -> void:
	_surfaces[_index(col, row)] = s


func vertex(col: int, row: int) -> Vector3:
	return Vector3(origin.x + col * cell, get_h(col, row), origin.y + row * cell)


## Height of the ground at a point; a point outside the grid gets the height of the nearest edge.
func height_at(x: float, z: float) -> float:
	var s := _sample(x, z)
	return s.x


func slope_deg_at(x: float, z: float) -> float:
	var s := _sample(x, z)
	return rad_to_deg(atan(Vector2(s.y, s.z).length()))


## Height, then the height gradient along x and along z, in the triangle the point falls in.
func _sample(x: float, z: float) -> Vector3:
	var u := clampf((x - origin.x) / cell, 0.0, float(cols - 1))
	var v := clampf((z - origin.y) / cell, 0.0, float(rows - 1))
	var c := mini(int(u), cols - 2)
	var r := mini(int(v), rows - 2)
	var fx := u - c
	var fz := v - r
	var h00 := get_h(c, r)
	var h11 := get_h(c + 1, r + 1)
	var dx: float
	var dz: float
	if fx >= fz:
		var h10 := get_h(c + 1, r)
		dx = h10 - h00
		dz = h11 - h10
	else:
		var h01 := get_h(c, r + 1)
		dx = h11 - h01
		dz = h01 - h00
	return Vector3(h00 + fx * dx + fz * dz, dx / cell, dz / cell)


func _index(col: int, row: int) -> int:
	return clampi(row, 0, rows - 1) * cols + clampi(col, 0, cols - 1)
