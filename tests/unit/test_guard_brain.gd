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
var noise_radii: Array = []


func before_each() -> void:
	brain = GuardBrain.new()
	alarms = []
	states = []
	brain.alarm_raised.connect(_on_alarm)
	brain.state_changed.connect(_on_state)


func after_each() -> void:
	# A guard killed in a test leaves a Body behind; later tests must not see it.
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()


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


func test_investigate_far_becomes_suspicious_with_fresh_total() -> void:
	_to_investigate()
	brain.tick(0.5, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)
	assert_eq(brain.goal_pos, SEEN_AT)
	brain.tick(0.9, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS, "1.4 s so far")
	brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM)


func test_investigate_hear_retargets_and_restarts_arrival() -> void:
	_to_investigate()
	brain.notify_arrived()
	brain.tick(3.9, NONE, Vector3.ZERO, false)
	states.clear()
	var next := Vector3(9, 0, 9)
	brain.hear(next)
	assert_eq(brain.goal_pos, next)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE)
	assert_false(brain.has_arrived())
	assert_eq(states, [], "same state, nothing to announce")
	brain.tick(10.0, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.INVESTIGATE, "the wait starts again on arrival")


func test_repeated_noise_cannot_cancel_building_suspicion() -> void:
	# A noise every 0.5 s (a running unit) with the target in the far zone throughout.
	for i in 15:
		if i % 5 == 0:
			brain.hear(HEARD_AT)
		brain.tick(0.1, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.ALARM, "1.5 s of far sight in total, noise or not")
	assert_eq(alarms, [SEEN_AT])


func test_far_total_is_cleared_by_going_back_on_patrol() -> void:
	brain.tick(1.0, FAR, SEEN_AT, false)
	brain.hear(HEARD_AT)
	brain.notify_arrived()
	brain.tick(4.0, NONE, Vector3.ZERO, false)
	assert_eq(brain.state, GuardBrain.State.PATROL)
	brain.tick(1.4, FAR, SEEN_AT, false)
	assert_eq(brain.state, GuardBrain.State.SUSPICIOUS)


func test_alarm_updated_only_with_sight_while_in_alarm() -> void:
	var updates: Array = []
	brain.alarm_updated.connect(func(p: Vector3) -> void: updates.append(p))
	brain.tick(0.1, NEAR, SEEN_AT, false)
	assert_eq(updates, [], "entering is announced by alarm_raised")
	var moved := Vector3(1, 0, 1)
	brain.tick(0.1, FAR, moved, false)
	brain.tick(0.1, NEAR, moved, false)
	assert_eq(updates, [moved, moved], "once per vision check, far or near")
	brain.tick(0.1, NONE, Vector3.ZERO, false)
	brain.tick(0.1, NONE, moved, true)
	brain.on_alarm(moved)
	assert_eq(updates.size(), 2, "not without sight, nor when told by a peer")


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


func test_peer_follows_a_moving_target_and_stays_in_the_fight() -> void:
	var seer := _guard()
	var peer := _guard(Vector3(30, 0, 0))
	var raised := [0]
	peer.brain.alarm_raised.connect(func(_p: Vector3) -> void: raised[0] += 1)
	var spec := _specialist(Vector3(0, 0, -10))
	seer.brain.tick(0.1, NEAR, spec.global_position, false)
	peer.brain.tick(29.9, NONE, Vector3.ZERO, false)
	spec.global_position = Vector3(2, 0, -10)
	seer.advance(0.1)
	assert_almost_eq(peer.brain.goal_pos, spec.global_position, Vector3.ONE * 0.001, "goal follows")
	peer.brain.tick(29.9, NONE, Vector3.ZERO, false)
	assert_eq(peer.brain.state, GuardBrain.State.ALARM, "no-sight timer was reset")
	peer.brain.tick(0.1, NONE, Vector3.ZERO, false)
	assert_eq(peer.brain.state, GuardBrain.State.PATROL)
	assert_eq(raised, [0], "the peer never raises it itself")


func test_updates_reach_guards_spawned_earlier_too() -> void:
	var peer := _guard(Vector3(30, 0, 0))
	var seer := _guard()
	var spec := _specialist(Vector3(0, 0, -10))
	seer.brain.tick(0.1, NEAR, spec.global_position, false)
	spec.global_position = Vector3(2, 0, -10)
	seer.advance(0.1)
	assert_almost_eq(peer.brain.goal_pos, spec.global_position, Vector3.ONE * 0.001)


func test_new_noise_redirects_an_investigating_guard() -> void:
	var g := _guard()
	NoiseBus.emit_noise(Vector3(0, 0, 3), 8.0)
	g.brain.notify_arrived()
	g.stop()
	NoiseBus.emit_noise(Vector3(3, 0, 0), 8.0)
	assert_eq(g.brain.goal_pos, Vector3(3, 0, 0))
	assert_true(g._moving, "walks to the new noise")


func _count_noise(_pos: Vector3, radius: float) -> void:
	noise_radii.append(radius)


func test_rifle_fire_makes_noise() -> void:
	var g := _guard()
	_specialist(Vector3(0, 0, -10))
	g.brain.on_alarm(Vector3(0, 0, -10))
	noise_radii = []
	NoiseBus.noise_emitted.connect(_count_noise)
	_run(g, 1.6)
	NoiseBus.noise_emitted.disconnect(_count_noise)
	assert_eq(noise_radii, [35.0])


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


# --- Patrol: a guard stops at each end of its beat, turns where it can be seen to, then walks ---

const EAST := Vector3(10, 0, 0)
const WEST := Vector3(-10, 0, 0)


## Which way a guard faces on the ground plane.
func _facing(g: Guard) -> Vector3:
	var f := -g.global_basis.z
	return Vector3(f.x, 0, f.z).normalized()


func _beat_guard() -> Guard:
	var g := _guard(EAST)
	g.set_route(PackedVector3Array([EAST, WEST]))
	g.rotation.y = -PI / 2.0  # facing east, having just walked there
	return g


func test_patrol_starts_by_walking_to_the_next_point_without_ceremony() -> void:
	var g := _beat_guard()
	g.start_patrol()
	assert_eq(g.current_waypoint(), 1, "it stands on the first point, so it heads for the second")
	assert_false(g.is_looking_round())
	assert_almost_eq(_target(g), WEST, Vector3.ONE * 0.01)


func test_at_the_end_of_a_beat_a_guard_stops_turns_and_waits_before_walking_back() -> void:
	var g := _beat_guard()
	g.start_patrol()
	g.global_position = WEST
	g.rotation.y = PI / 2.0  # facing west
	g.arrived.emit(g)
	assert_true(g.is_looking_round())
	assert_eq(g.current_waypoint(), 0)
	assert_eq(g.velocity, Vector3.ZERO)
	# Half a turn at the turn speed, then the pause.
	var turn_seconds: float = 180.0 / g.tuning.turn_speed_deg
	_run(g, turn_seconds * 0.5)
	assert_true(g.is_looking_round())
	assert_lt(absf(_facing(g).x), 0.35, "half way round it faces across its beat")
	_run(g, turn_seconds * 0.5 + 0.1)
	assert_almost_eq(_facing(g), Vector3(1, 0, 0), Vector3.ONE * 0.02, "now facing back the way it came")
	assert_true(g.is_looking_round(), "and still waiting")
	_run(g, g.tuning.waypoint_pause + 0.1)
	assert_false(g.is_looking_round())
	assert_almost_eq(_target(g), EAST, Vector3.ONE * 0.01)


func test_an_about_turn_always_goes_clockwise() -> void:
	# Seen from above with north up: east, then south, then west. A player can learn it.
	var g := _guard(WEST)
	g.set_route(PackedVector3Array([WEST, EAST]))
	g.start_patrol()  # heads for the east end
	g.global_position = EAST
	g.rotation.y = -PI / 2.0  # and arrives there facing east
	g.arrived.emit(g)
	_run(g, 90.0 / g.tuning.turn_speed_deg)
	assert_almost_eq(_facing(g), Vector3(0, 0, 1), Vector3.ONE * 0.1, "from east it swings through the south")
	var other := _beat_guard()
	other.start_patrol()
	other.global_position = WEST
	other.rotation.y = PI / 2.0
	other.arrived.emit(other)
	_run(other, 90.0 / other.tuning.turn_speed_deg)
	assert_almost_eq(_facing(other), Vector3(0, 0, -1), Vector3.ONE * 0.1, "from west it swings through the north")


func test_a_corner_is_turned_the_short_way() -> void:
	var g := _guard(Vector3.ZERO)
	g.set_route(PackedVector3Array([Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, -5)]))
	g.start_patrol()
	g.global_position = Vector3(5, 0, 0)
	g.rotation.y = -PI / 2.0  # arrived walking east; the next leg goes north
	g.arrived.emit(g)
	_run(g, 45.0 / g.tuning.turn_speed_deg)
	var f := _facing(g)
	assert_gt(f.x, 0.5, "between east")
	assert_lt(f.z, -0.5, "and north: the quarter turn, not the three quarters")


func test_an_alarm_cuts_the_look_round_short() -> void:
	var g := _beat_guard()
	g.start_patrol()
	g.global_position = WEST
	g.arrived.emit(g)
	assert_true(g.is_looking_round())
	g.brain.on_alarm(Vector3(0, 0, 8))
	assert_false(g.is_looking_round())
	assert_almost_eq(_target(g), Vector3(0, 0, 8), Vector3.ONE * 0.01)


func test_a_guard_loaded_while_looking_round_takes_up_its_beat_again() -> void:
	var g := _beat_guard()
	g.start_patrol()
	g.global_position = WEST
	g.rotation.y = PI / 2.0
	g.arrived.emit(g)
	_run(g, 0.3)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.save_state()))
	var other := _guard()
	other.set_route(PackedVector3Array([EAST, WEST]))
	other.load_state(saved)
	assert_true(other.is_looking_round(), "it does not stand there for ever")
	_run(other, 180.0 / other.tuning.turn_speed_deg + other.tuning.waypoint_pause + 0.2)
	assert_false(other.is_looking_round())
	assert_almost_eq(_target(other), EAST, Vector3.ONE * 0.01)


func _target(g: Guard) -> Vector3:
	return (g.get_node("NavigationAgent3D") as NavigationAgent3D).target_position
