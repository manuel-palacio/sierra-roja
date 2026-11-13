class_name SoldierGear
extends RefCounted
## What each kind of soldier wears and carries on top of the uniform: a helmet or cap, a rifle,
## a bag. Each piece is a plain shape fixed to a bone, so it moves with the animation. Display only.
## Pieces are placed in the model's own space as it stands at rest (metres, y up, facing +z).

const STEEL := Color(0.25, 0.28, 0.22)
const WOOD := Color(0.30, 0.20, 0.12)
const GUNMETAL := Color(0.13, 0.13, 0.14)
const CANVAS := Color(0.55, 0.50, 0.36)

const BLADE := Color(0.72, 0.74, 0.78)
const FIELD_GREY := Color(0.30, 0.36, 0.39)
const FUR := Color(0.38, 0.32, 0.26)
const SHIELD_RED := Color(0.72, 0.10, 0.10)
const SHIELD_YELLOW := Color(0.92, 0.76, 0.12)
## The bones of the arm that holds a weapon.
const HAND := "DEF-hand.R"
const FOREARM := "DEF-forearm.R"

## Kit name -> pieces. A piece: the bone it rides on, "sphere" or "box", its size, where its
## centre is, how it is turned (degrees), and its colour.
## "when" says when it is shown: always if absent; &"slung" until the rifle is in use; or the
## name of the action that brings it out (&"rifle", &"pistol", &"knife").
## A "held" piece is a weapon in the hand instead: its length, thickness, and how far from its
## near end the hand grips it. It lies along the forearm, so it points where the arm points; a
## rifle is gripped well forward, which puts its butt back at the shoulder of the outstretched arm.
const KITS := {
	&"guard": [
		# Steel helmet with a slight brim, and a rifle slung across the back.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.20, 0.34), "at": Vector3(0, 1.775, 0.01), "color": STEEL },
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.37, 0.05, 0.40), "at": Vector3(0, 1.725, 0.01), "color": STEEL },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.05, 0.07), "at": Vector3(0.02, 1.28, -0.17), "turn": Vector3(0, 0, 28), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.03, 0.45, 0.03), "at": Vector3(-0.19, 1.66, -0.17), "turn": Vector3(0, 0, 28), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.05, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.42, "thick": 0.03, "grip": -0.37, "color": GUNMETAL, "when": &"rifle" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.30, 0.10, 0.06), "at": Vector3(0, 1.12, 0.13), "color": Color(0.36, 0.24, 0.14) },
	],
	&"dynamiter": [
		# Black beret, red neckerchief, and the satchel of charges on the hip.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.33, 0.11, 0.34), "at": Vector3(0.02, 1.81, 0.0), "turn": Vector3(0, 0, -8), "color": Color(0.10, 0.10, 0.12) },
		{ "bone": "DEF-neck", "shape": "sphere", "size": Vector3(0.19, 0.075, 0.19), "at": Vector3(0, 1.515, 0.015), "color": Color(0.75, 0.13, 0.10) },
		{ "bone": "DEF-hips", "shape": "box", "size": Vector3(0.12, 0.26, 0.30), "at": Vector3(-0.21, 0.93, 0.0), "color": CANVAS },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "held": 0.30, "thick": 0.03, "grip": 0.08, "color": BLADE, "when": &"knife" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, 38), "color": Color(0.42, 0.37, 0.26) },
	],
	# Winter in Spain: what each wears, under a blanket worn over the shoulders.
	&"guard_winter": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.20, 0.34), "at": Vector3(0, 1.775, 0.01), "color": STEEL },
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.37, 0.05, 0.40), "at": Vector3(0, 1.725, 0.01), "color": STEEL },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.05, 0.07), "at": Vector3(0.02, 1.28, -0.17), "turn": Vector3(0, 0, 28), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.03, 0.45, 0.03), "at": Vector3(-0.19, 1.66, -0.17), "turn": Vector3(0, 0, 28), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.05, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.42, "thick": 0.03, "grip": -0.37, "color": GUNMETAL, "when": &"rifle" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.30, 0.10, 0.06), "at": Vector3(0, 1.12, 0.13), "color": Color(0.36, 0.24, 0.14) },
		{ "bone": "DEF-spine.003", "shape": "sphere", "size": Vector3(0.64, 0.40, 0.44), "at": Vector3(0, 1.38, -0.01), "color": Color(0.45, 0.43, 0.40) },
	],
	&"dynamiter_winter": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.33, 0.11, 0.34), "at": Vector3(0.02, 1.81, 0.0), "turn": Vector3(0, 0, -8), "color": Color(0.10, 0.10, 0.12) },
		{ "bone": "DEF-neck", "shape": "sphere", "size": Vector3(0.19, 0.075, 0.19), "at": Vector3(0, 1.515, 0.015), "color": Color(0.75, 0.13, 0.10) },
		{ "bone": "DEF-hips", "shape": "box", "size": Vector3(0.12, 0.26, 0.30), "at": Vector3(-0.21, 0.93, 0.0), "color": CANVAS },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "held": 0.30, "thick": 0.03, "grip": 0.08, "color": BLADE, "when": &"knife" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, 38), "color": Color(0.42, 0.37, 0.26) },
		{ "bone": "DEF-spine.003", "shape": "sphere", "size": Vector3(0.64, 0.40, 0.44), "at": Vector3(0, 1.38, -0.01), "color": Color(0.40, 0.31, 0.23) },
	],
	&"marksman_winter": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.09, 0.36), "at": Vector3(0, 1.80, 0.03), "color": Color(0.33, 0.28, 0.22) },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.25, 0.07), "at": Vector3(0.02, 1.30, -0.17), "turn": Vector3(0, 0, -30), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.035, 0.30, 0.035), "at": Vector3(0.12, 1.50, -0.215), "turn": Vector3(0, 0, -30), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.25, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.50, "thick": 0.03, "grip": -0.57, "color": GUNMETAL, "when": &"rifle" },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, -38), "color": Color(0.30, 0.20, 0.12) },
		{ "bone": "DEF-spine.003", "shape": "sphere", "size": Vector3(0.64, 0.40, 0.44), "at": Vector3(0, 1.38, -0.01), "color": Color(0.36, 0.35, 0.31) },
	],
	# The División Azul: the German helmet's flare in field grey, a greatcoat's skirt, and on the
	# right sleeve the red-yellow-red shield of the Spanish volunteers. No other insignia.
	&"guard_blue": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.20, 0.34), "at": Vector3(0, 1.775, 0.01), "color": FIELD_GREY },
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.37, 0.05, 0.40), "at": Vector3(0, 1.725, 0.01), "color": FIELD_GREY },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.05, 0.07), "at": Vector3(0.02, 1.28, -0.17), "turn": Vector3(0, 0, 28), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.03, 0.45, 0.03), "at": Vector3(-0.19, 1.66, -0.17), "turn": Vector3(0, 0, 28), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.05, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.42, "thick": 0.03, "grip": -0.37, "color": GUNMETAL, "when": &"rifle" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.30, 0.10, 0.06), "at": Vector3(0, 1.12, 0.13), "color": Color(0.36, 0.24, 0.14) },
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.41, 0.09, 0.40), "at": Vector3(0, 1.695, -0.035), "color": FIELD_GREY },
		{ "bone": "DEF-hips", "shape": "box", "size": Vector3(0.37, 0.40, 0.25), "at": Vector3(0, 0.80, -0.01), "color": Color(0.33, 0.40, 0.43) },
		{ "bone": "DEF-upper_arm.R", "shape": "box", "size": Vector3(0.03, 0.02, 0.075), "at": Vector3(-0.265, 1.502, -0.07), "color": SHIELD_RED },
		{ "bone": "DEF-upper_arm.R", "shape": "box", "size": Vector3(0.03, 0.02, 0.075), "at": Vector3(-0.295, 1.502, -0.07), "color": SHIELD_YELLOW },
		{ "bone": "DEF-upper_arm.R", "shape": "box", "size": Vector3(0.03, 0.02, 0.075), "at": Vector3(-0.325, 1.502, -0.07), "color": SHIELD_RED },
	],
	# The pair in Russia: fur caps, and their own weapons and bags.
	&"dynamiter_russia": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.35, 0.21, 0.37), "at": Vector3(0, 1.785, 0.0), "color": FUR },
		{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.05, 0.15, 0.15), "at": Vector3(0.168, 1.70, -0.01), "color": FUR },
		{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.05, 0.15, 0.15), "at": Vector3(-0.168, 1.70, -0.01), "color": FUR },
		{ "bone": "DEF-hips", "shape": "box", "size": Vector3(0.12, 0.26, 0.30), "at": Vector3(-0.21, 0.93, 0.0), "color": CANVAS },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "held": 0.30, "thick": 0.03, "grip": 0.08, "color": BLADE, "when": &"knife" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, 38), "color": Color(0.42, 0.37, 0.26) },
	],
	&"marksman_russia": [
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.35, 0.21, 0.37), "at": Vector3(0, 1.785, 0.0), "color": FUR },
		{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.05, 0.15, 0.15), "at": Vector3(0.168, 1.70, -0.01), "color": FUR },
		{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.05, 0.15, 0.15), "at": Vector3(-0.168, 1.70, -0.01), "color": FUR },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.25, 0.07), "at": Vector3(0.02, 1.30, -0.17), "turn": Vector3(0, 0, -30), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.035, 0.30, 0.035), "at": Vector3(0.12, 1.50, -0.215), "turn": Vector3(0, 0, -30), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.25, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.50, "thick": 0.03, "grip": -0.57, "color": GUNMETAL, "when": &"rifle" },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, -38), "color": Color(0.30, 0.20, 0.12) },
	],
	# Nothing but what he was taken in.
	&"prisoner": [],
	&"marksman": [
		# Flat cap and the long rifle across the back.
		{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.31, 0.09, 0.36), "at": Vector3(0, 1.80, 0.03), "color": Color(0.33, 0.28, 0.22) },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.05, 1.25, 0.07), "at": Vector3(0.02, 1.30, -0.17), "turn": Vector3(0, 0, -30), "color": WOOD, "when": &"slung" },
		{ "bone": "DEF-spine.003", "shape": "box", "size": Vector3(0.035, 0.30, 0.035), "at": Vector3(0.12, 1.50, -0.215), "turn": Vector3(0, 0, -30), "color": GUNMETAL, "when": &"slung" },
		{ "held": 1.25, "thick": 0.06, "grip": 0.60, "color": WOOD, "when": &"rifle" },
		{ "held": 0.50, "thick": 0.03, "grip": -0.57, "color": GUNMETAL, "when": &"rifle" },
		{ "held": 0.24, "thick": 0.05, "grip": 0.05, "color": GUNMETAL, "when": &"pistol" },
		{ "bone": "DEF-spine.002", "shape": "box", "size": Vector3(0.05, 0.56, 0.02), "at": Vector3(0.0, 1.27, 0.125), "turn": Vector3(0, 0, -38), "color": Color(0.30, 0.20, 0.12) },
	],
}

## What every soldier has under the hat: eyes, brows, a nose and a mouth, so a face looks back
## when the camera is close.
const FACE := [
	{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.036, 0.026, 0.02), "at": Vector3(0.030, 1.700, 0.101), "color": Color(0.08, 0.06, 0.05) },
	{ "bone": "DEF-head", "shape": "sphere", "size": Vector3(0.036, 0.026, 0.02), "at": Vector3(-0.030, 1.700, 0.101), "color": Color(0.08, 0.06, 0.05) },
	{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.046, 0.012, 0.015), "at": Vector3(0.031, 1.724, 0.103), "turn": Vector3(0, 0, -8), "color": Color(0.20, 0.14, 0.10) },
	{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.046, 0.012, 0.015), "at": Vector3(-0.031, 1.724, 0.103), "turn": Vector3(0, 0, 8), "color": Color(0.20, 0.14, 0.10) },
	{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.026, 0.050, 0.034), "at": Vector3(0, 1.672, 0.106), "color": Color(0.72, 0.52, 0.40) },
	{ "bone": "DEF-head", "shape": "box", "size": Vector3(0.056, 0.012, 0.014), "at": Vector3(0, 1.624, 0.104), "color": Color(0.42, 0.22, 0.18) },
]
## Kit name -> a moustache or stubble colour for its mouth line, where it has one.
const WHISKERS := { &"guard": Color(0.16, 0.11, 0.08), &"marksman": Color(0.30, 0.20, 0.13),
		&"prisoner": Color(0.35, 0.30, 0.26), &"guard_winter": Color(0.16, 0.11, 0.08),
		&"guard_blue": Color(0.16, 0.11, 0.08), &"marksman_winter": Color(0.30, 0.20, 0.13),
		&"marksman_russia": Color(0.30, 0.20, 0.13) }

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
	for piece: Dictionary in pieces(kit):
		var bone_name: String = HAND if piece.has("held") else piece["bone"]
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		var mesh := MeshInstance3D.new()
		mesh.material_override = _material(piece["color"])
		var rest := skeleton.get_bone_global_rest(bone)
		if piece.has("held"):
			mesh.mesh = _shape("box", Vector3(piece["held"], piece["thick"], piece["thick"]))
			mesh.transform = rest.affine_inverse() * _held(skeleton, piece)
		else:
			mesh.mesh = _shape(piece["shape"], piece["size"])
			var turn: Vector3 = piece.get("turn", Vector3.ZERO)
			var in_model := Transform3D(Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))),
					piece["at"])
			# Where the piece sits relative to its bone when the model is at rest.
			mesh.transform = rest.affine_inverse() * to_skeleton * in_model
		var when: StringName = piece.get("when", &"")
		mesh.set_meta("when", when)
		mesh.visible = when == &"" or when == &"slung"
		attachment.add_child(mesh)
		made.append(mesh)
	return made


## Where a held weapon lies in the skeleton's space at rest: along the line from forearm to hand,
## with the hand `grip` metres from its near end.
static func _held(skeleton: Skeleton3D, piece: Dictionary) -> Transform3D:
	var hand := skeleton.get_bone_global_rest(skeleton.find_bone(HAND)).origin
	var forearm := skeleton.get_bone_global_rest(skeleton.find_bone(FOREARM)).origin
	var along := (hand - forearm).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	var length: float = piece["held"]
	var centre := hand + along * (0.08 + length / 2.0 - float(piece["grip"])) + up * 0.07
	return Transform3D(Basis(along, up, side), centre)


## Everything a kit puts on a model: the face, then what it wears and carries.
static func pieces(kit: StringName) -> Array:
	var out: Array = []
	for part: Dictionary in FACE:
		out.append(part)
	if WHISKERS.has(kit):
		# A moustache over the mouth.
		out.append({ "bone": "DEF-head", "shape": "box", "size": Vector3(0.084, 0.024, 0.02),
				"at": Vector3(0, 1.643, 0.108), "color": WHISKERS[kit] })
	out.append_array(KITS[kit])
	return out


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
