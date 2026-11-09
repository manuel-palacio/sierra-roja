class_name UnitVisual
extends Node
## Display only. Dresses the parent Unit's model in its uniform, plays its idle, walk, sprint and
## die animations to match what the unit is doing, lays it face down while it crawls, and sets
## its feet on the drawn ground (the unit itself stands on the navmesh, which runs a little above
## or below). It reads the unit and never writes to it, and collision stays as it is.

## A lying model is this high off the ground at its middle, and this far back so it is centred
## on the unit instead of stretching out ahead of it.
const PRONE_HEIGHT := 0.3
const PRONE_BACK := 0.85
const CRAWL_ANIMATION_SPEED := 0.5
## The model is never moved further than this from the unit's own height.
const MAX_GROUND_SHIFT := 0.5

## Replaces the texture the model came with.
@export var uniform: Texture2D
## The flat colour the unit shows in where something stands between it and the camera.
@export var silhouette := Color(0.55, 0.75, 1.0, 0.75)

var _unit: Unit
var _player: AnimationPlayer
var _model: Node3D
var _rest := Transform3D.IDENTITY
var _current := &""


func _ready() -> void:
	_unit = get_parent() as Unit
	_player = _find_player(_unit)
	# Runs while paused so a load made during a pause shows the loaded stance at once.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_model = _unit.get_node_or_null("Model") as Node3D
	if _model != null:
		_rest = _model.transform
		dress(_model, uniform)
		show_through(_model, silhouette)


func _process(_delta: float) -> void:
	if _unit == null:
		return
	var crawling := _unit.stance == Unit.Stance.CRAWLING and _unit.alive
	if _model != null:
		var pose := _rest
		if crawling:
			# Tipped forward about the unit's side-to-side axis, head toward where it faces (-z).
			pose = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0) * _rest.basis,
					_rest.origin + Vector3(0.0, PRONE_HEIGHT, PRONE_BACK))
		pose.origin.y += _ground_shift()
		_model.transform = pose
	if _player != null:
		_player.speed_scale = CRAWL_ANIMATION_SPEED if crawling else 1.0
		_play(_wanted(crawling))


## Gives every mesh under a model a copy of its material with this texture. Used for bodies too.
static func dress(model: Node, texture: Texture2D) -> void:
	if texture == null:
		return
	var dressed := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			if not dressed.has(material):
				var copy := material.duplicate() as BaseMaterial3D
				copy.albedo_texture = texture
				dressed[material] = copy
			mesh.set_surface_override_material(i, dressed[material])


## Makes every mesh under a model show in one flat colour wherever something stands between it
## and the camera (the engine's stencil x-ray: the model marks its own pixels, so its own limbs
## do not count as something in the way). Each material is copied once to carry the setting.
static func show_through(model: Node, color: Color) -> void:
	var copies := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			if not copies.has(material):
				var copy := material.duplicate() as BaseMaterial3D
				copy.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
				copy.stencil_color = color
				copies[material] = copy
			mesh.set_surface_override_material(i, copies[material])


## How far the drawn ground under the unit is above (or below) the height the unit stands at.
func _ground_shift() -> float:
	if not _unit.is_inside_tree():
		return 0.0
	var from := _unit.global_position + Vector3.UP * (MAX_GROUND_SHIFT + 0.5)
	var to := _unit.global_position + Vector3.DOWN * (MAX_GROUND_SHIFT + 1.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, Unit.LAYER_WORLD)
	var hit := _unit.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.has("position"):
		return 0.0
	return clampf(hit["position"].y - _unit.global_position.y, -MAX_GROUND_SHIFT, MAX_GROUND_SHIFT)


func _wanted(crawling: bool) -> StringName:
	if not _unit.alive:
		return &"die"
	var speed := Vector2(_unit.velocity.x, _unit.velocity.z).length()
	if crawling:
		# The legs and arms work while it moves and hold still while it lies.
		return &"walk" if speed >= 0.1 else &"static"
	if speed < 0.1:
		return &"idle"
	return &"sprint" if speed > _unit.stats.walk_speed * 1.2 else &"walk"


func _play(anim: StringName) -> void:
	if anim == _current or not _player.has_animation(anim):
		return
	_current = anim
	_player.play(anim, 0.15)


func _find_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_player(child)
		if found != null:
			return found
	return null
