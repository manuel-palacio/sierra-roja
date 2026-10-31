class_name UnitVisual
extends Node
## Display only. Plays the placeholder model's idle, walk, sprint and die animations to match
## what the parent Unit is doing. It reads the unit and never writes to it.

var _unit: Unit
var _player: AnimationPlayer
var _current := &""


func _ready() -> void:
	_unit = get_parent() as Unit
	_player = _find_player(_unit)


func _process(_delta: float) -> void:
	if _unit == null or _player == null:
		return
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
