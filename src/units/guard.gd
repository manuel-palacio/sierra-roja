class_name Guard
extends Unit
## A guard's senses and body: looks every vision_interval, listens to NoiseBus, walks its route
## and fires its rifle. GuardBrain decides; this carries it out.
##
## Alarm sharing is wired here, through the `guards` group: each guard connects to every other
## guard's brain.alarm_raised and alarm_updated as it enters the tree, so it needs no Mission and survives any
## order of spawning.

signal fired(target: Specialist)

const GROUP := "guards"

@export var tuning: GuardTuning
@export var vision: GuardVision

var brain: GuardBrain
## Vision checks so far; shows the checks run on a timer rather than every frame.
var vision_checks := 0

var _route := PackedVector3Array()
var _waypoint := 0
var _vision_timer := 0.0
var _fire_timer := 0.0
var _alarm_dest := Vector3.INF
var _stuck_time := 0.0
var _stuck_anchor := Vector3.ZERO


func _ready() -> void:
	super()
	if tuning == null:
		tuning = GuardTuning.defaults()
	if vision == null:
		vision = Vision.defaults()
	brain = GuardBrain.new(tuning)
	brain.state_changed.connect(_on_state_changed)
	arrived.connect(_on_arrived)
	died.connect(_on_died)
	NoiseBus.noise_emitted.connect(_on_noise)
	var peers := get_tree().get_nodes_in_group(GROUP)
	_vision_timer = (peers.size() % 3) * tuning.vision_interval / 3.0
	for node in peers:
		var peer := node as Guard
		peer.brain.alarm_raised.connect(_on_peer_alarm)
		peer.brain.alarm_updated.connect(_on_peer_alarm)
		brain.alarm_raised.connect(peer._on_peer_alarm)
		brain.alarm_updated.connect(peer._on_peer_alarm)
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	super(delta)
	advance(delta)


## Far range for this guard's vision: longer once it has been through an alarm.
func current_far_range() -> float:
	return vision.alarm_far_range if brain.alerted else vision.far_range


func set_route(points: PackedVector3Array) -> void:
	_route = points
	_waypoint = 0


func route_size() -> int:
	return _route.size()


func current_waypoint() -> int:
	return _waypoint


func vision_phase() -> float:
	return _vision_timer


func start_patrol() -> void:
	_apply_state()


## One step of everything but walking. Tests call this directly to run with no waiting.
func advance(delta: float) -> void:
	if not alive:
		return
	_update_stuck(delta)
	_vision_timer -= delta
	if _vision_timer > 0.0:
		return
	_vision_timer += tuning.vision_interval
	_check_vision(tuning.vision_interval)


func save_state() -> Dictionary:
	var d := super()
	d["brain"] = brain.save_state()
	d["waypoint"] = _waypoint
	d["fire_timer"] = _fire_timer
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	brain.load_state(d["brain"])
	_waypoint = int(d["waypoint"])
	_apply_state()
	_fire_timer = float(d["fire_timer"])


func _check_vision(elapsed: float) -> void:
	vision_checks += 1
	var target := _strongest_target()
	var zone: Vision.Zone = target["zone"]
	var spec: Specialist = target["specialist"]
	var body := _find_body()
	var pos := Vector3.ZERO
	if spec != null:
		pos = spec.global_position
	elif body != null:
		pos = body.global_position
	brain.tick(elapsed, zone, pos, body != null)
	match brain.state:
		GuardBrain.State.SUSPICIOUS:
			if spec != null:
				_face(pos)
		GuardBrain.State.ALARM:
			_act_in_alarm(spec, elapsed)


func _strongest_target() -> Dictionary:
	var best_zone := Vision.Zone.NONE
	var best: Specialist = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(Specialist.GROUP):
		var spec := node as Specialist
		if not spec.alive:
			continue
		var zone := Perception.sees(self, spec, vision.target_height(spec.stance),
				current_far_range(), vision)
		if zone == Vision.Zone.NONE:
			continue
		var dist := _flat_distance(spec.global_position)
		if zone > best_zone or (zone == best_zone and dist < best_dist):
			best_zone = zone
			best = spec
			best_dist = dist
	return { "zone": best_zone, "specialist": best }


## A body is low and lies still, so it follows the crawling rule: near zone only.
func _find_body() -> Body:
	for node in get_tree().get_nodes_in_group(Body.GROUP):
		var body := node as Body
		if body.found or body.carried_by != null:
			continue
		var zone := Perception.sees(self, body, vision.target_height_crawling, current_far_range(), vision)
		if zone != Vision.Zone.NONE:
			body.found = true
			return body
	return null


func _act_in_alarm(spec: Specialist, elapsed: float) -> void:
	_fire_timer = maxf(_fire_timer - elapsed, 0.0)
	if spec != null and _flat_distance(spec.global_position) <= tuning.fire_range:
		stop()
		_alarm_dest = Vector3.INF
		_face(spec.global_position)
		if _fire_timer <= GuardBrain.EPSILON:
			_fire_timer = tuning.fire_interval
			spec.take_damage(tuning.rifle_damage)
			fired.emit(spec)
			NoiseBus.emit_noise(global_position, tuning.rifle_noise_radius)
	elif _alarm_dest.distance_to(brain.goal_pos) > 1.0:
		_alarm_dest = brain.goal_pos
		move_to(brain.goal_pos, true)


func _update_stuck(delta: float) -> void:
	if not _moving or global_position.distance_to(_stuck_anchor) >= tuning.stuck_progress:
		_stuck_anchor = global_position
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= tuning.stuck_time - GuardBrain.EPSILON:
		_stuck_time = 0.0
		stop()
		_on_arrived(self)


## However the guard died (knife, shot, blast), a Body takes its place. The Body is added to
## the guard's own parent, which outlives the guard.
func _on_died(_unit: Unit) -> void:
	remove_from_group(GROUP)
	var parent := get_parent()
	if parent != null:
		var body := (load(Body.SCENE) as PackedScene).instantiate() as Body
		parent.add_child(body)
		body.global_position = global_position
		body.rotation.y = rotation.y
	queue_free()


func _on_arrived(_unit: Unit) -> void:
	match brain.state:
		GuardBrain.State.PATROL:
			if not _route.is_empty():
				_waypoint = (_waypoint + 1) % _route.size()
			_walk_route()
		GuardBrain.State.INVESTIGATE:
			brain.notify_arrived()


func _on_state_changed(_state: GuardBrain.State) -> void:
	_stuck_time = 0.0
	_fire_timer = tuning.fire_interval
	_apply_state()


## Puts the body in line with the brain's state, on a change or after a load.
func _apply_state() -> void:
	_alarm_dest = Vector3.INF
	match brain.state:
		GuardBrain.State.PATROL:
			_walk_route()
		GuardBrain.State.SUSPICIOUS:
			stop()
		GuardBrain.State.INVESTIGATE:
			if brain.has_arrived():
				stop()
			else:
				move_to(brain.goal_pos)
		GuardBrain.State.ALARM:
			move_to(brain.goal_pos, true)
			_alarm_dest = brain.goal_pos


func _walk_route() -> void:
	if _route.is_empty():
		stop()
	else:
		move_to(_route[_waypoint])


func _on_noise(pos: Vector3, radius: float) -> void:
	if alive and global_position.distance_to(pos) <= radius:
		brain.hear(pos)
		# Also covers a new noise while investigating, which changes the goal but not the state.
		if brain.state == GuardBrain.State.INVESTIGATE:
			_apply_state()


func _on_peer_alarm(pos: Vector3) -> void:
	if alive:
		brain.on_alarm(pos)


func _face(pos: Vector3) -> void:
	var to := pos - global_position
	rotation.y = atan2(-to.x, -to.z)


func _flat_distance(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
