class_name UnitVisual
extends Node
## Display only. Dresses the parent Unit's soldier model in its uniform and kit, plays the
## animation that matches what the unit is doing (standing, walking, running, crawling, dead),
## and sets its feet on the drawn ground (the unit itself stands on the navmesh, which runs a
## little above or below). It reads the unit and never writes to it, and collision stays as it is.

const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Sprint"
const DIE := &"Death01"
## Lying flat and moving on the belly. The library's swimming clip is a body stretched out face
## down with the arms working, which on the ground is a crawl; held still, it is lying in wait.
const CRAWL := &"Swim_Fwd"
const LOOPING: Array[StringName] = [IDLE, WALK, RUN, CRAWL]
## The swimming clip holds the body this far above the model's origin; a crawling model is
## lowered by it (times the model's own scale) so the body lies on the ground.
const CRAWL_DROP := 0.74
const CRAWL_ANIMATION_SPEED := 0.7
const BLEND := 0.2
## Metres per second from which a unit counts as moving.
const MOVING := 0.1
## The model is never moved further than this from the unit's own height to meet the ground.
const MAX_GROUND_SHIFT := 0.5

## The palette the model's body parts are coloured from (tools/make_soldier.py).
@export var uniform: Texture2D
## What it wears and carries: a key of SoldierGear.KITS.
@export var kit := &""
## The flat colour the unit shows in where something stands between it and the camera.
@export var silhouette := Color(0.55, 0.75, 1.0, 0.75)

var _unit: Unit
var _player: AnimationPlayer
var _model: Node3D
var _rest := Transform3D.IDENTITY
var _current := &""
## Seconds since the animation last changed.
var _since_change := 0.0


func _ready() -> void:
	_unit = get_parent() as Unit
	_player = _find_player(_unit)
	# Runs while paused so a load made during a pause shows the loaded stance at once.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_model = _unit.get_node_or_null("Model") as Node3D
	if _model != null:
		_rest = _model.transform
		dress(_model, uniform)
		SoldierGear.equip(_model, kit)
		show_through(_model, silhouette)
	if _player != null:
		for clip in LOOPING:
			if _player.has_animation(clip):
				_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		_play(_wanted(false))


func _process(delta: float) -> void:
	if _unit == null:
		return
	_since_change += delta
	var crawling := _unit.stance == Unit.Stance.CRAWLING and _unit.alive
	if _model != null:
		var pose := _rest
		if crawling:
			pose.origin.y -= CRAWL_DROP * _rest.basis.get_scale().y
		pose.origin.y += _ground_shift()
		_model.transform = pose
	if _player != null:
		_play(_wanted(crawling))
		_player.speed_scale = 1.0
		if crawling:
			# Lying still holds the clip where it is, but only once the change of pose has blended
			# in: a stopped player would stop the blend too, half way down.
			var still := _ground_speed() < MOVING and _since_change > BLEND
			_player.speed_scale = 0.0 if still else CRAWL_ANIMATION_SPEED


## The animation playing now.
func current_animation() -> StringName:
	return _current


## Colours a soldier model from a uniform palette: every skinned mesh gets a copy of its material
## with the palette as its texture. Used for bodies too.
static func dress(model: Node, texture: Texture2D) -> void:
	if texture == null:
		return
	var dressed := {}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null:
			continue
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			if not dressed.has(material):
				var copy := material.duplicate() as BaseMaterial3D
				copy.albedo_texture = texture
				# Each body part reads one flat square of the palette.
				copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				copy.roughness = 1.0
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
			if mesh.material_override != null:
				mesh.material_override = copies[material]
			else:
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
		return DIE
	if crawling:
		return CRAWL
	var speed := _ground_speed()
	if speed < MOVING:
		return IDLE
	return RUN if speed > _unit.stats.walk_speed * 1.2 else WALK


func _ground_speed() -> float:
	return Vector2(_unit.velocity.x, _unit.velocity.z).length()


func _play(anim: StringName) -> void:
	if anim == _current or not _player.has_animation(anim):
		return
	_current = anim
	_since_change = 0.0
	_player.play(anim, BLEND)


func _find_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_player(child)
		if found != null:
			return found
	return null
