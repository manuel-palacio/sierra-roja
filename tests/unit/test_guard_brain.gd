extends GutTest
## Decisions are tested by driving GuardBrain.tick directly (no scene tree, no waiting).
## Guard scene tests turn physics off and drive Guard.advance, so they run in no real time.

const NEAR := Vision.Zone.NEAR
const FAR := Vision.Zone.FAR
const NONE := Vision.Zone.NONE
const SEEN_AT := Vector3(5, 0, -5)
const HEARD_AT := Vector3(-3, 0, 2)

var brain: GuardBrain
var alarms: Array = []
var states: Array = []


func before_each() -> void:
	brain = GuardBrain.new()
	alarms = []
	states = []
	brain.alarm_raised.connect(_on_alarm)
	brain.state_changed.connect(_on_state)


func _on_alarm(pos: Vector3) -> void:
	alarms.append(pos)


func _on_state(state: GuardBrain.State) -> void:
	states.append(state)


func _to_suspicious() -> void:
	brain.tick(0.1, FAR, SEEN_AT, false)


func _to_investigate() -> void:
	brain.hear(HEARD_AT)


func _to_alarm() -> void:
	brain.tick(0.1, NEAR, SEEN_AT, false)


# --- state table ---

func test_near_raises_alarm_from_any_state() -> void:
	brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM, "from PATROL")
	assert_eq(alarms, [SEEN_AT])

	brain = GuardBrain.new()
	_to_suspicious()
	brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM, "from SUSPICIOUS")

	brain = GuardBrain.new()
	_to_investigate()
	brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM, "from INVESTIGATE")


func test_body_seen_raises_alarm() -> void:
	brain.tick(0.1, NONE, SEEN_AT, true)
	assert_eq(brain.state, GuardBrain.State.ALARM)
	assert_eq(alarms, [SEEN_AT])


func test_on_alarm_moves_to_alarm_without_reemitting() -> void:
	brain.on_alarm(SEEN_AT)
	assert_eq(brain.state, GuardBrain.State.ALARM)
	assert_eq(brain.goal_pos, SEEN_AT)
	assert_eq(alarms, [], "a shared alarm must not be raised again or guards would loop")


func test_alarm_is_raised_once_while_in_alarm() -> void:
	_to_alarm()
	brain.tick(0.1, NEAR, SEEN_AT, true)
	assert_eq(alarms.size(), 1)
	assert_eq(states, [GuardBrain.State.ALARM])


func test_patrol_far_becomes_suspicious() -> void:
	brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)
	assert_eq(brain.goal_pos, SEEN_AT)
	assert_eq(alarms, [])


func test_suspicious_far_for_1_5s_in_total_raises_alarm() -> void:
	brain.tick(0.5, FAR, SEEN_AT, false)
	brain.tick(1.0, NONE, SEEN_AT, false) # a gap does not clear the total
	brain.tick(0.5, FAR, SEEN_AT, false)
	brain.tick(0.4, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS, "1.4 s so far")
	brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM)
	assert_eq(alarms, [SEEN_AT])


func test_suspicious_far_in_tenths_reaches_alarm_on_time() -> void:
	for i in 14:
		brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)
	brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM)


func test_suspicious_no_sight_3s_investigates_last_position() -> void:
	_to_suspicious()
	brain.tick(2.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)
	brain.tick(0.1, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)
	assert_eq(brain.goal_pos, SEEN_AT)


func test_suspicious_no_sight_timer_restarts_on_sight() -> void:
	_to_suspicious()
	brain.tick(2.9, NONE, Vector3.ZERO, false)
	brain.tick(0.1, FAR, SEEN_AT, false)
	brain.tick(2.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)


func test_patrol_hear_investigates_position() -> void:
	brain.hear(HEARD_AT)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)
	assert_eq(brain.goal_pos, HEARD_AT)


func test_suspicious_hear_investigates_position() -> void:
	_to_suspicious()
	brain.hear(HEARD_AT)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)
	assert_eq(brain.goal_pos, HEARD_AT)


func test_hear_does_not_override_alarm() -> void:
	_to_alarm()
	brain.hear(HEARD_AT)
	assert_eq(brain.state, GuardBrain.State.ALARM)
	assert_eq(brain.goal_pos, SEEN_AT)


func test_investigate_returns_to_patrol_4s_after_arriving() -> void:
	_to_investigate()
	brain.tick(10.0, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE, "the wait starts on arrival")
	brain.notify_arrived()
	brain.tick(3.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)
	brain.tick(0.1, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.PATROL)


func test_investigate_wait_needs_no_sight() -> void:
	_to_investigate()
	brain.notify_arrived()
	brain.tick(3.9, NONE, Vector3.ZERO, false)
	brain.tick(0.1, FAR, SEEN_AT, false)
	brain.tick(3.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)


func test_alarm_no_sight_30s_stands_down_alerted() -> void:
	_to_alarm()
	assert_false(brain.alerted)
	brain.tick(29.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.ALARM)
	brain.tick(0.1, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.PATROL)
	assert_true(brain.alerted)


func test_alarm_timer_restarts_on_sight() -> void:
	_to_alarm()
	brain.tick(29.9, NONE, Vector3.ZERO, false)
	brain.tick(0.1, FAR, Vector3(1, 0, 1), false)
	assert_eq(brain.goal_pos, Vector3(1, 0, 1), "the last known position follows the target")
	brain.tick(29.9, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.ALARM)


func test_alert_persists_after_stand_down() -> void:
	_to_alarm()
	brain.tick(30.0, NONE, Vector3.ZERO, false)
	assert_true(brain.alerted)
	_to_investigate()
	brain.notify_arrived()
	brain.tick(4.0, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.PATROL)
	assert_true(brain.alerted, "still alerted after a later patrol")
	assert_eq(alarms.size(), 1)


func test_save_load_resumes_timers_silently() -> void:
	brain.tick(1.0, FAR, SEEN_AT, false)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(brain.save_state()))
	var other := GuardBrain.new()
	other.alarm_raised.connect(_on_alarm)
	other.state_changed.connect(_on_state)
	states.clear()
	other.load_state(saved)
	assert_eq(other.state, GuardBrain.State.SUSPICIOUS)
	assert_eq(other.goal_pos, SEEN_AT)
	assert_eq(states, [], "loading does not announce a change")
	other.tick(0.4, FAR, SEEN_AT, false)
	assert_eq(other.state, GuardBrain.State.SUSPICIOUS)
	other.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(other.state, GuardBrain.State.ALARM)


func test_save_load_keeps_alerted_and_arrival() -> void:
	_to_alarm()
	brain.tick(30.0, NONE, Vector3.ZERO, false)
	_to_investigate()
	brain.notify_arrived()
	var other := GuardBrain.new()
	other.load_state(JSON.parse_string(JSON.stringify(brain.save_state())))
	assert_true(other.alerted)
	other.tick(4.0, NONE, Vector3.ZERO, false)
	assert_eq(other.state, GuardBrain.State.PATROL, "still counted as arrived")


# --- Guard, driven by hand ---

func _guard(pos := Vector3.ZERO) -> Guard:
	var g: Guard = load("res://scenes/units/guard.tscn").instantiate()
	add_child_autofree(g)
	g.set_physics_process(false)
	g.global_position = pos
	return g


func _specialist(pos: Vector3) -> Specialist:
	var s: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	add_child_autofree(s)
	s.set_physics_process(false)
	s.global_position = pos
	return s


func _body(pos: Vector3) -> Body:
	var b: Body = load("res://scenes/units/body.tscn").instantiate()
	add_child_autofree(b)
	b.global_position = pos
	return b


func _run(g: Guard, seconds: float) -> void:
	for i in roundi(seconds * 10.0):
		g.advance(0.1)


func test_guards_share_alarm() -> void:
	var a := _guard(Vector3(0, 0, 0))
	var b := _guard(Vector3(30, 0, 0))
	var c := _guard(Vector3(-30, 0, 0))
	var raised := [0, 0, 0]
	a.brain.alarm_raised.connect(func(_p: Vector3) -> void: raised[0] += 1)
	b.brain.alarm_raised.connect(func(_p: Vector3) -> void: raised[1] += 1)
	c.brain.alarm_raised.connect(func(_p: Vector3) -> void: raised[2] += 1)
	b.brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(a.brain.state, GuardBrain.State.ALARM)
	assert_eq(c.brain.state, GuardBrain.State.ALARM)
	assert_eq(a.brain.goal_pos, SEEN_AT)
	assert_eq(raised, [0, 1, 0], "only the guard who saw it raises the alarm")


func test_noise_within_radius_is_investigated() -> void:
	var g := _guard()
	NoiseBus.emit_noise(Vector3(0, 0, 8), 8.0)
	assert_eq(g.brain.state, GuardBrain.State.INVESTIGATE)
	assert_eq(g.brain.goal_pos, Vector3(0, 0, 8))


func test_noise_outside_radius_ignored() -> void:
	var g := _guard()
	NoiseBus.emit_noise(Vector3(0, 0, 8.5), 8.0)
	assert_eq(g.brain.state, GuardBrain.State.PATROL)


func test_dead_guard_does_nothing() -> void:
	var dead := _guard()
	var other := _guard(Vector3(30, 0, 0))
	var spec := _specialist(Vector3(0, 0, -3))
	dead.take_damage(1000)
	NoiseBus.emit_noise(Vector3.ZERO, 8.0)
	assert_eq(dead.brain.state, GuardBrain.State.PATROL, "ignores noise")
	_run(dead, 3.0)
	assert_eq(dead.brain.state, GuardBrain.State.PATROL, "ignores what is in front of it")
	other.brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(dead.brain.state, GuardBrain.State.PATROL, "ignores a shared alarm")
	dead.brain.on_alarm(SEEN_AT) # even a forced alarm cannot make it shoot
	_run(dead, 3.0)
	assert_eq(spec.hp, 100)


func test_freed_guard_leaves_noise_bus() -> void:
	var count := NoiseBus.noise_emitted.get_connections().size()
	var g: Guard = load("res://scenes/units/guard.tscn").instantiate()
	add_child(g)
	assert_eq(NoiseBus.noise_emitted.get_connections().size(), count + 1)
	remove_child(g)
	g.free()
	assert_eq(NoiseBus.noise_emitted.get_connections().size(), count)


func test_stuck_guard_picks_next_waypoint() -> void:
	var g := _guard()
	g.set_route(PackedVector3Array([Vector3(0, 0, 5), Vector3(5, 0, 5), Vector3(5, 0, 0)]))
	g.start_patrol()
	assert_eq(g.current_waypoint(), 0)
	_run(g, 2.9)
	assert_eq(g.current_waypoint(), 0)
	_run(g, 0.2)
	assert_eq(g.current_waypoint(), 1)
	_run(g, 3.1)
	assert_eq(g.current_waypoint(), 2)


func test_stuck_investigating_guard_counts_as_arrived() -> void:
	var g := _guard()
	g.brain.hear(HEARD_AT)
	_run(g, 3.1)
	assert_eq(g.brain.state, GuardBrain.State.INVESTIGATE)
	_run(g, 4.1)
	assert_eq(g.brain.state, GuardBrain.State.PATROL)


func test_guard_fires_every_1_5s_in_alarm_with_sight() -> void:
	var g := _guard()
	var spec := _specialist(Vector3(0, 0, -10))
	g.brain.on_alarm(spec.global_position)
	_run(g, 1.4)
	assert_eq(spec.hp, 100, "no shot before the first interval")
	_run(g, 0.2)
	assert_eq(spec.hp, 66, "one shot of 34")
	_run(g, 1.4)
	assert_eq(spec.hp, 32, "second shot at 3 s")


func test_guard_does_not_fire_without_sight() -> void:
	var g := _guard()
	var spec := _specialist(Vector3(0, 0, 10)) # behind the guard
	g.brain.on_alarm(Vector3(0, 0, -10))
	_run(g, 4.0)
	assert_eq(spec.hp, 100)


func test_guard_does_not_fire_outside_alarm() -> void:
	var g := _guard()
	var spec := _specialist(Vector3(0, 0, -10))
	_run(g, 1.0) # seen in the far zone: suspicious, not yet alarm
	assert_eq(g.brain.state, GuardBrain.State.SUSPICIOUS)
	assert_eq(spec.hp, 100)


func test_guard_does_not_fire_beyond_14m() -> void:
	var g := _guard()
	g.brain.alerted = true
	var spec := _specialist(Vector3(0, 0, -16)) # seen at 18 m range, out of rifle range
	g.brain.on_alarm(spec.global_position)
	_run(g, 4.0)
	assert_eq(spec.hp, 100)


func test_dead_specialist_is_ignored() -> void:
	var g := _guard()
	var spec := _specialist(Vector3(0, 0, -3))
	spec.take_damage(1000)
	_run(g, 1.0)
	assert_eq(g.brain.state, GuardBrain.State.PATROL)


func test_guard_reports_strongest_zone() -> void:
	var g := _guard()
	_specialist(Vector3(0, 0, -10))
	_specialist(Vector3(0, 0, -3))
	g.advance(0.1)
	assert_eq(g.brain.state, GuardBrain.State.ALARM)
	assert_almost_eq(g.brain.goal_pos, Vector3(0, 0, -3), Vector3.ONE * 0.001)


func test_guard_faces_target_when_suspicious() -> void:
	var g := _guard()
	_specialist(Vector3(4, 0, -10))
	g.rotation.y = -0.2
	g.advance(0.1)
	assert_eq(g.brain.state, GuardBrain.State.SUSPICIOUS)
	assert_almost_eq(g.rotation.y, atan2(-4.0, 10.0), 0.001)


func test_current_far_range_grows_once_alerted() -> void:
	var g := _guard()
	assert_eq(g.current_far_range(), 14.0)
	g.brain.alerted = true
	assert_eq(g.current_far_range(), 18.0)


func test_body_is_found_once_in_near_zone() -> void:
	var g := _guard()
	var b := _body(Vector3(0, 0, -5))
	g.advance(0.1)
	assert_true(b.found)
	assert_eq(g.brain.state, GuardBrain.State.ALARM)
	assert_eq(g.brain.goal_pos, b.global_position)
	# Found already: the next guard is not alarmed by it.
	var other := _guard(Vector3(0, 0, 0))
	other.advance(0.1)
	assert_eq(other.brain.state, GuardBrain.State.PATROL)


func test_body_in_far_zone_is_not_seen() -> void:
	var g := _guard()
	var b := _body(Vector3(0, 0, -8))
	g.advance(0.1)
	assert_false(b.found)
	assert_eq(g.brain.state, GuardBrain.State.PATROL)


func test_carried_body_is_not_seen() -> void:
	var g := _guard()
	var b := _body(Vector3(0, 0, -5))
	b.carried_by = _specialist(Vector3(0, 0, 40))
	g.advance(0.1)
	assert_false(b.found)
	assert_eq(g.brain.state, GuardBrain.State.PATROL)


func test_vision_runs_every_0_1s_not_every_frame() -> void:
	var g := _guard()
	for i in 60:
		g.advance(1.0 / 60.0)
	assert_between(g.vision_checks, 9, 11)


func test_vision_checks_are_staggered() -> void:
	var phases := [_guard().vision_phase(), _guard().vision_phase(), _guard().vision_phase()]
	assert_ne(phases[0], phases[1])
	assert_ne(phases[1], phases[2])
	assert_ne(phases[0], phases[2])


func test_guard_save_load_roundtrip() -> void:
	var g := _guard(Vector3(2, 0, 3))
	g.set_route(PackedVector3Array([Vector3(0, 0, 5), Vector3(5, 0, 5)]))
	g.start_patrol()
	_run(g, 3.1)
	g.brain.tick(0.1, FAR, SEEN_AT, false)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.save_state()))
	var other := _guard()
	other.set_route(PackedVector3Array([Vector3(0, 0, 5), Vector3(5, 0, 5)]))
	other.load_state(saved)
	assert_almost_eq(other.global_position, Vector3(2, 0, 3), Vector3.ONE * 0.001)
	assert_eq(other.current_waypoint(), 1)
	assert_eq(other.brain.state, GuardBrain.State.SUSPICIOUS)
