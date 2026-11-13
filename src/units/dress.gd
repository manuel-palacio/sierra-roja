class_name Dress
extends RefCounted
## What a mission dresses its units in. A unit's scene gives it a kit and a uniform; a mission
## with a dress swaps them for that dress's, by the kit's name. Looks only: nothing in the rules
## knows what anyone wears.

## dress -> the scene's kit -> the kit worn instead.
const KITS := {
	&"spain_winter": { &"guard": &"guard_winter", &"dynamiter": &"dynamiter_winter", &"marksman": &"marksman_winter" },
	&"russia": { &"guard": &"guard_blue", &"dynamiter": &"dynamiter_russia", &"marksman": &"marksman_russia" },
}
## dress -> the scene's kit -> the uniform worn instead of the scene's own.
const UNIFORMS := {
	&"russia": {
		&"guard": preload("res://assets/characters/soldier/uniform-guard_blue.png"),
		&"dynamiter": preload("res://assets/characters/soldier/uniform-dynamiter_russia.png"),
		&"marksman": preload("res://assets/characters/soldier/uniform-marksman_russia.png"),
	},
}


static func kit(dress: StringName, base: StringName) -> StringName:
	return KITS.get(dress, {}).get(base, base)


static func uniform(dress: StringName, base: StringName, fallback: Texture2D) -> Texture2D:
	return UNIFORMS.get(dress, {}).get(base, fallback)


## The dress of the mission a node stands in; &"" when it stands in none.
static func of(node: Node) -> StringName:
	var above := node.get_parent()
	while above != null:
		if above is Mission:
			return (above as Mission).dress
		above = above.get_parent()
	return &""
