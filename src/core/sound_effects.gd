class_name SoundEffects
extends Node
## Display only: plays the placeholder sounds. It listens to NoiseBus and to each guard's alarm
## signal and never changes game state. Browsers keep audio locked until the first click or key;
## Godot starts it then, so earlier sounds are simply silent.

enum Kind { FOOTSTEP, SHOT, EXPLOSION }

## NoiseBus carries a radius, not a kind. A running unit is 8 m, a pistol 20, a rifle 35, a charge 80.
const FOOTSTEP_MAX_RADIUS := 10.0
const SHOT_MAX_RADIUS := 40.0
const MAX_VOICES := 12
const ALARM_COOLDOWN_MSEC := 3000

const FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_1.ogg"),
	preload("res://assets/audio/footstep_2.ogg"),
]
const SHOT: AudioStream = preload("res://assets/audio/gunshot.wav")
const EXPLOSION: AudioStream = preload("res://assets/audio/explosion.mp3")
const ALARM: AudioStream = preload("res://assets/audio/alarm.ogg")

var _voices := 0
var _last_alarm_msec := -ALARM_COOLDOWN_MSEC
var _hooked := {}


static func classify(radius: float) -> Kind:
	if radius <= FOOTSTEP_MAX_RADIUS:
		return Kind.FOOTSTEP
	return Kind.SHOT if radius <= SHOT_MAX_RADIUS else Kind.EXPLOSION


func _ready() -> void:
	NoiseBus.noise_emitted.connect(_on_noise)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group(Guard.GROUP):
		_hook(node as Guard)


func _on_noise(pos: Vector3, radius: float) -> void:
	match classify(radius):
		Kind.FOOTSTEP:
			_play_at(FOOTSTEPS[randi() % FOOTSTEPS.size()], pos, -6.0, randf_range(0.9, 1.1))
		Kind.SHOT:
			_play_at(SHOT, pos, 0.0, randf_range(0.95, 1.05))
		Kind.EXPLOSION:
			_play_at(EXPLOSION, pos, 3.0, 1.0)


func _on_node_added(node: Node) -> void:
	if node is Guard:
		_hook.call_deferred(node)  # its brain exists once it is ready


func _hook(guard: Guard) -> void:
	if guard == null or guard.brain == null or _hooked.has(guard.get_instance_id()):
		return
	_hooked[guard.get_instance_id()] = true
	guard.brain.alarm_raised.connect(_on_alarm)


func _on_alarm(_pos: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_alarm_msec < ALARM_COOLDOWN_MSEC:
		return
	_last_alarm_msec = now
	var player := AudioStreamPlayer.new()
	player.stream = ALARM
	player.volume_db = -4.0
	_start(player)


func _play_at(stream: AudioStream, pos: Vector3, volume_db: float, pitch: float) -> void:
	if _voices >= MAX_VOICES:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 30.0
	player.max_distance = 150.0
	_start(player, pos)


func _start(player: Node, pos := Vector3.INF) -> void:
	_voices += 1
	add_child(player)
	if player is AudioStreamPlayer3D and pos != Vector3.INF:
		(player as AudioStreamPlayer3D).global_position = pos
	player.finished.connect(func() -> void:
		_voices -= 1
		player.queue_free())
	player.call("play")
