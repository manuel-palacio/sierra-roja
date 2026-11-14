class_name SilenceObjective
extends Objective
## Met when every named sentry is dead. Until then it is against a clock, and against any alarm:
## the clock running out, or any guard of the mission reaching ALARM, and it can no longer be met.
## A shot fired before then is an alarm in itself, whoever is near enough to hear it: the bank is
## awake. Once the last sentry is down none of this matters any more. This is a rule of this
## objective only: what guards see, hear and do about it is as everywhere else.

const TOO_LATE_TEXT := "The boats came in under the sentries' guns"
const ALARM_TEXT := "The alarm was raised before the boats crossed"
const SHOT_TEXT := "A shot was heard along the bank before the boats crossed"
## A noise this loud or louder is a shot (or a blast): a pistol's, the quietest, carries this far.
const SHOT_NOISE := 15.0

## The sentries, by their names under the mission's Guards node.
@export var sentries: PackedStringArray
## How long there is, in seconds of play.
@export var seconds := 300.0

## Seconds of play left on the clock.
var time_left := 0.0

var _reason := ""
## A guard has been in ALARM since the last time this was reset, even if he is dead by now.
var _alarm_raised := false
## A shot has been fired since then.
var _shot_heard := false


func _ready() -> void:
	time_left = seconds


func setup(mission: Mission, rules: MissionRules) -> void:
	super(mission, rules)
	if not NoiseBus.noise_emitted.is_connected(_on_noise):
		NoiseBus.noise_emitted.connect(_on_noise)
	for guard in mission.guards():
		_listen_to(guard)


## Sentries still alive.
func sentries_left() -> int:
	var left := 0
	for guard in _named():
		if guard.alive:
			left += 1
	return left


func current_hud_text() -> String:
	var whole := int(ceilf(time_left))
	return tr("%s: %d left. Boats in %d:%02d") % [tr(hud_text), sentries_left(), whole / 60, whole % 60]


## The pointer leads to the sentry nearest the first specialist still alive.
func marker_position() -> Vector3:
	var from := Vector3.ZERO
	for s in _mission.specialists() if _mission else []:
		if s.alive:
			from = s.global_position
			break
	var best := Vector3.ZERO
	var best_distance := INF
	for guard in _named():
		if guard.alive and guard.global_position.distance_to(from) < best_distance:
			best_distance = guard.global_position.distance_to(from)
			best = guard.global_position
	return best


func _physics_process(delta: float) -> void:
	if done or failed or _rules == null:
		return
	if _rules.result != MissionRules.Result.RUNNING or not _rules.clock_running:
		return
	time_left = maxf(time_left - delta, 0.0)


## The dead are counted first: the last sentry going down settles it, whatever else that moment
## held.
func update() -> void:
	if done or failed or _mission == null:
		return
	if sentries_left() == 0:
		complete()
		return
	for guard in _mission.guards():
		# A guard put back by a load is a new node: heard from here on.
		_listen_to(guard)
		if guard.alive and guard.brain.state == GuardBrain.State.ALARM:
			_alarm_raised = true
	if _shot_heard:
		failed = true
		_reason = SHOT_TEXT
	elif _alarm_raised:
		failed = true
		_reason = ALARM_TEXT
	elif time_left <= 0.0:
		failed = true
		_reason = TOO_LATE_TEXT


func fail_reason() -> String:
	return _reason if failed else ""


func save_state() -> Dictionary:
	var d := super()
	d["time_left"] = time_left
	return d


func load_state(d: Dictionary) -> void:
	super(d)
	time_left = float(d["time_left"])
	_alarm_raised = false
	_shot_heard = false
	_reason = ""


func state_ok(d: Variant) -> bool:
	if not super(d):
		return false
	var left: Variant = d.get("time_left")
	return (left is float or left is int) and is_finite(float(left)) and float(left) >= 0.0 and float(left) <= seconds


func validate(mission: Mission, _map: RID, _from: Vector3) -> PackedStringArray:
	var errors := PackedStringArray()
	if sentries.is_empty():
		errors.append("%s: there are no sentries to silence" % name)
	var holder := mission.get_node_or_null("Guards")
	for sentry in sentries:
		if holder == null or not holder.get_node_or_null(NodePath(sentry)) is Guard:
			errors.append("%s: there is no guard called %s" % [name, sentry])
	if seconds <= 0.0:
		errors.append("%s: the clock has no time on it" % name)
	return errors


func _named() -> Array[Guard]:
	var out: Array[Guard] = []
	var holder := _mission.get_node_or_null("Guards") if _mission else null
	if holder == null:
		return out
	for sentry in sentries:
		var guard := holder.get_node_or_null(NodePath(sentry)) as Guard
		if guard != null:
			out.append(guard)
	return out


func _listen_to(guard: Guard) -> void:
	if not guard.brain.state_changed.is_connected(_on_guard_state):
		guard.brain.state_changed.connect(_on_guard_state)


func _on_noise(_pos: Vector3, radius: float) -> void:
	if radius >= SHOT_NOISE and not done:
		_shot_heard = true


func _on_guard_state(state: GuardBrain.State) -> void:
	if state == GuardBrain.State.ALARM and not done:
		_alarm_raised = true
