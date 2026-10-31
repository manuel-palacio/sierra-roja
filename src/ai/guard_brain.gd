class_name GuardBrain
extends RefCounted
## A guard's decisions: which state it is in and where it should go. No scene access, so it
## runs with no scene tree. Guard feeds it what it sees and hears, and acts on the result.

signal state_changed(state: State)
signal alarm_raised(pos: Vector3)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, ALARM }

## Timers add up many 0.1 s steps; this keeps float error from costing a step.
const EPSILON := 0.00001

var state := State.PATROL
## Set for good by the first stand-down; lengthens the guard's far range.
var alerted := false
## Where the guard is headed: the last known target position, or the noise it heard.
var goal_pos := Vector3.ZERO
var tuning: GuardTuning

var _far_total := 0.0
var _no_sight := 0.0
var _wait := 0.0
var _arrived := false


func _init(t: GuardTuning = null) -> void:
	tuning = t if t != null else GuardTuning.defaults()


## One vision check. target_pos is only read when something is seen.
func tick(delta: float, sight: Vision.Zone, target_pos: Vector3, body_seen: bool) -> void:
	if sight == Vision.Zone.NEAR or body_seen:
		_alarm(target_pos, true)
		return
	var far := sight == Vision.Zone.FAR
	match state:
		State.PATROL:
			if far:
				goal_pos = target_pos
				_enter(State.SUSPICIOUS)
				_far_total = delta
		State.SUSPICIOUS:
			if far:
				goal_pos = target_pos
				_no_sight = 0.0
				_far_total += delta
				if _reached(_far_total, tuning.far_time_to_alarm):
					_alarm(target_pos, true)
			else:
				_no_sight += delta
				if _reached(_no_sight, tuning.suspicious_no_sight):
					_enter(State.INVESTIGATE)
		State.INVESTIGATE:
			if far:
				_wait = 0.0
			elif _arrived:
				_wait += delta
				if _reached(_wait, tuning.investigate_wait):
					_enter(State.PATROL)
		State.ALARM:
			if far:
				goal_pos = target_pos
				_no_sight = 0.0
			else:
				_no_sight += delta
				if _reached(_no_sight, tuning.alarm_stand_down):
					alerted = true
					_enter(State.PATROL)


func hear(pos: Vector3) -> void:
	if state == State.PATROL or state == State.SUSPICIOUS:
		goal_pos = pos
		_enter(State.INVESTIGATE)


## Another guard raised the alarm. Does not emit alarm_raised, so guards don't loop.
func on_alarm(pos: Vector3) -> void:
	_alarm(pos, false)


## The guard reached the spot it was investigating; the wait starts now.
func notify_arrived() -> void:
	if state == State.INVESTIGATE:
		_arrived = true


func has_arrived() -> bool:
	return _arrived


## JSON-safe snapshot (no Vector3 or enums). Signal connections are not saved.
func save_state() -> Dictionary:
	return {
		"state": int(state),
		"alerted": alerted,
		"goal": [goal_pos.x, goal_pos.y, goal_pos.z],
		"far_total": _far_total,
		"no_sight": _no_sight,
		"wait": _wait,
		"arrived": _arrived,
	}


## Restores silently: nothing changed from the game's point of view.
func load_state(d: Dictionary) -> void:
	state = int(d["state"]) as State
	alerted = bool(d["alerted"])
	var g: Array = d["goal"]
	goal_pos = Vector3(g[0], g[1], g[2])
	_far_total = float(d["far_total"])
	_no_sight = float(d["no_sight"])
	_wait = float(d["wait"])
	_arrived = bool(d["arrived"])


func _alarm(pos: Vector3, announce: bool) -> void:
	goal_pos = pos
	if state == State.ALARM:
		_no_sight = 0.0
		return
	_enter(State.ALARM)
	if announce:
		alarm_raised.emit(pos)


func _enter(next: State) -> void:
	state = next
	_far_total = 0.0
	_no_sight = 0.0
	_wait = 0.0
	_arrived = false
	state_changed.emit(next)


static func _reached(value: float, limit: float) -> bool:
	return value >= limit - EPSILON
