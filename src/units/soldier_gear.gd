class_name SoldierGear
extends RefCounted
## What each kind of soldier wears and carries on top of the uniform: a helmet or cap, a rifle,
## a bag. Each piece is a plain shape fixed to a bone, so it moves with the animation. Display only.
## Pieces are placed in the model's own space as it stands at rest (metres, y up, facing +z).

const STEEL := Color(0.25, 0.28, 0.22)
const WOOD := Color(0.30, 0.20, 0.12)
const GUNMETAL := Color(0.13, 0.13, 0.14)
const CANVAS := Color(0.55, 0.50, 0.36)

## Kit name -> pieces. A piece: the bone it rides on, "sphere" or "box", its size, where its
## centre is, how it is turned (degrees), and its colour.
const KITS := {
	&"guard": [
		# Steel helmet with a slight brim, and a rifle slung across the back.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.20, 0.34), "at": Vector3(0, 1.775, 0.01), "color": STEEL },
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.37, 0.05, 0.40), "at": Vector3(0, 1.725, 0.01), "color": STEEL },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.05, 0.07), "at": Vector3(0.02, 1.28, -0.17), "turn": Vector3(0, 0, 28), "color": WOOD },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.03, 0.45, 0.03), "at": Vector3(-0.19, 1.66, -0.17), "turn": Vector3(0, 0, 28), "color": GUNMETAL },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.30, 0.10, 0.06), "at": Vector3(0, 1.12, 0.13), "color": Color(0.36, 0.24, 0.14) },
	],
	&"dynamiter": [
		# Black beret, red neckerchief, and the satchel of charges on the hip.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.33, 0.11, 0.34), "at": Vector3(0.02, 1.81, 0.0), "turn": Vector3(0, 0, -8), "color": Color(0.10, 0.10, 0.12) },
		{ "bone": "DEF-neck", "shape": "box", "size": Vector3(0.20, 0.07, 0.19), "at": Vector3(0, 1.51, 0.02), "color": Color(0.75, 0.13, 0.10) },
		{ "bone": "DEF-hips", "shape": "box", "size": Vector3(0.12, 0.26, 0.30), "at": Vector3(-0.21, 0.93, 0.0), "color": CANVAS },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, 38), "color": Color(0.42, 0.37, 0.26) },
	],
	&"marksman": [
		# Flat cap and the long rifle across the back.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.09, 0.36), "at": Vector3(0, 1.80, 0.03), "color": Color(0.33, 0.28, 0.22) },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.25, 0.07), "at": Vector3(0.02, 1.30, -0.17), "turn": Vector3(0, 0, -30), "color": WOOD },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.035, 0.30, 0.035), "at": Vector3(0.12, 1.50, -0.215), "turn": Vector3(0, 0, -30), "color": GUNMETAL },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, -38), "color": Color(0.30, 0.20, 0.12) },
	],
}

static var _materials: Dictionary = {}


## Puts a kit on a model. Returns the pieces made (none for an unknown kit or a model with no
## skeleton), each a MeshInstance3D under a BoneAttachment3D on the model's skeleton.
static func equip(model: Node3D, kit: StringName) -> Array[MeshInstance3D]:
	var made: Array[MeshInstance3D] = []
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty() or not KITS.has(kit):
		return made
	var skeleton := skeletons[0] as Skeleton3D
	# From the model's space to the skeleton's.
	var to_skeleton := Transform3D.IDENTITY
	var node: Node3D = skeleton
	while node != null and node != model:
		to_skeleton = node.transform * to_skeleton
		node = node.get_parent() as Node3D
	to_skeleton = to_skeleton.affine_inverse()
	for piece: Dictionary in KITS[kit]:
		var bone := skeleton.find_bone(piece["bone"])
		if bone < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = piece["bone"]
		skeleton.add_child(attachment)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _shape(piece["shape"], piece["size"])
		mesh.material_override = _material(piece["color"])
		var turn: Vector3 = piece.get("turn", Vector3.ZERO)
		var in_model := Transform3D(Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))),
				piece["at"])
		# Where the piece sits relative to its bone when the model is at rest.
		mesh.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * to_skeleton * in_model
		attachment.add_child(mesh)
		made.append(mesh)
	return made


static func _shape(kind: String, size: Vector3) -> Mesh:
	if kind == "sphere":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 10
		sphere.rings = 5
		# A unit sphere squashed to the size wanted.
		var squashed := ArrayMesh.new()
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = verts[i] * size
		arrays[Mesh.ARRAY_VERTEX] = verts
		squashed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return squashed
	var box := BoxMesh.new()
	box.size = size
	return box


static func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials[color] = material
	return _materials[color]
