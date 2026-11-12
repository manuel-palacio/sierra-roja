class_name SoundEffects
extends Node
## Display only: plays the sounds. It listens to NoiseBus, to each guard's alarm signal, to
## every unit's `acted` (the knife) and for bodies falling, keeps a quiet morning going underneath,
## and never changes game state. Browsers keep audio locked until the first click or key;
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
const KNIFE: AudioStream = preload("res://assets/audio/knife.ogg")
const BODY_FALL: AudioStream = preload("res://assets/audio/body_fall.ogg")
const AMBIENCE: AudioStream = preload("res://assets/audio/birds.ogg")
const AMBIENCE_DB := -13.0
## How long a killed guard takes to reach the ground.
const FALL_SECONDS := 0.55

## The birdsong under everything.
var ambience: AudioStreamPlayer

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
	for group in [Guard.GROUP, Specialist.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			_hook_unit(node as Unit)
	(AMBIENCE as AudioStreamOggVorbis).loop = true
	ambience = AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.stream = AMBIENCE
	ambience.volume_db = AMBIENCE_DB
	ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambience)
	ambience.play()


## The one-shot sounds playing now.
func voices() -> Array[Node]:
	var out: Array[Node] = []
	for child in get_children():
		if child != ambience and not child is Timer:
			out.append(child)
	return out


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
	if node is Unit:
		_hook_unit(node as Unit)
	elif node is Body and (node as Body).fell_now:
		var body := node as Body
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = FALL_SECONDS
		add_child(timer)
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			if is_instance_valid(body) and body.is_inside_tree():
				_play_at(BODY_FALL, body.global_position, -2.0, randf_range(0.85, 1.0)))
		timer.start()


func _hook_unit(unit: Unit) -> void:
	if unit == null or _hooked.has(-unit.get_instance_id()):
		return
	_hooked[-unit.get_instance_id()] = true
	unit.acted.connect(func(what: StringName, _at: Vector3) -> void:
		# Shots are heard through their noise; the knife makes none.
		if what == &"knife" and is_instance_valid(unit):
			_play_at(KNIFE, unit.global_position, -3.0, randf_range(0.95, 1.05)))


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
