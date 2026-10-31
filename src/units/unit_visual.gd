class_name UnitVisual
extends Node
## Display only. Plays the placeholder model's idle, walk, sprint and die animations to match
## what the parent Unit is doing, and squashes the model while it crawls (the placeholder has no
## crawl animation). It reads the unit and never writes to it, and collision stays as it is.

## The model's height while crawling, as a share of its height standing.
const CRAWL_HEIGHT := 0.45

var _unit: Unit
var _player: AnimationPlayer
var _model: Node3D
var _rest_basis := Basis.IDENTITY
var _current := &""


func _ready() -> void:
	_unit = get_parent() as Unit
	_player = _find_player(_unit)
	# Runs while paused so a load made during a pause shows the loaded stance at once.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_model = _unit.get_node_or_null("Model") as Node3D
	if _model != null:
		_rest_basis = _model.basis


func _process(_delta: float) -> void:
	if _unit == null:
		return
	if _model != null:
		var height := CRAWL_HEIGHT if _unit.stance == Unit.Stance.CRAWLING else 1.0
		_model.basis = _rest_basis * Basis.from_scale(Vector3(1.0, height, 1.0))
	if _player != null:
		_play(_wanted())


func _wanted() -> StringName:
	if not _unit.alive:
		return &"die"
	var speed := Vector2(_unit.velocity.x, _unit.velocity.z).length()
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
