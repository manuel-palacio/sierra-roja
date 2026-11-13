class_name Surfaces
extends RefCounted
## The textured materials of built things: stone, plaster, roof tiles, planks, steel. Each lays
## its texture out in world space from three sides (triplanar), so plain boxes and generated
## shapes need no texture coordinates and neighbouring pieces line up.

const TEXTURES := {
	&"stone": preload("res://assets/textures/stone_wall.jpg"),
	&"plaster": preload("res://assets/textures/plaster.jpg"),
	&"roof": preload("res://assets/textures/roof_tiles.jpg"),
	&"planks": preload("res://assets/textures/planks.jpg"),
	&"steel": preload("res://assets/textures/steel.jpg"),
	&"rock": preload("res://assets/textures/rock.jpg"),
	&"bark": preload("res://assets/textures/bark.jpg"),
	&"leaves": preload("res://assets/textures/grass.jpg"),
}
## The relief of the ones that have any.
const NORMALS := {
	&"stone": preload("res://assets/textures/stone_wall_normal.jpg"),
	&"roof": preload("res://assets/textures/roof_tiles_normal.jpg"),
	&"planks": preload("res://assets/textures/planks_normal.jpg"),
	&"rock": preload("res://assets/textures/rock_normal.jpg"),
}
## Texture repeats per metre.
const TILING := { &"stone": 0.45, &"plaster": 0.3, &"roof": 0.55, &"planks": 0.7, &"steel": 0.5, &"rock": 0.3,
		&"bark": 0.8, &"leaves": 0.55 }

static var _made: Dictionary = {}


## Lying snow, for the tops of things in winter. One instance.
static func snow() -> StandardMaterial3D:
	var key := [&"snow"]
	if not _made.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Terrain.SNOW * 0.9
		m.roughness = 1.0
		m.metallic_specular = 0.1
		_made[key] = m
	return _made[key]


## The material for a surface kind, tinted. One instance per kind and tint.
static func material(kind: StringName, tint := Color.WHITE) -> StandardMaterial3D:
	var key := [kind, tint]
	if not _made.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = TEXTURES[kind]
		m.albedo_color = tint
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * float(TILING[kind])
		m.roughness = 1.0
		m.metallic_specular = 0.1
		if NORMALS.has(kind):
			m.normal_enabled = true
			m.normal_texture = NORMALS[kind]
			m.normal_scale = 1.2
		_made[key] = m
	return _made[key]
