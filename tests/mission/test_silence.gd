extends GutTest
## Sentries to silence against a clock, with no alarm raised.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var guards: Array[Guard]
var objective: SilenceObjective
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	await _build(false)


func after_each() -> void:
	_clock.release()
	get_tree().paused = false
	for group in [PlantedCharge.GROUP, Body.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			node.free()


func _build(live_guards: bool) -> void:
	mission = load("res://tests/fixtures/flat_bank.tscn").instantiate()
	if not live_guards:
		mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	rules = MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	guards = mission.guards()
	objective = mission.objectives()[0] as SilenceObjective


func _frames(n := 6) -> void:
	for i in n:
		await get_tree().physics_frame


func _kill(index: int) -> void:
	guards[index].take_damage(1000)


func test_the_fixture_is_a_sound_mission() -> void:
	assert_eq(MissionValidator.validate(mission), PackedStringArray())
	assert_eq(objective.sentries_left(), 3)
	assert_eq(objective.time_left, 60.0)


func test_all_three_down_and_it_is_met() -> void:
	for i in 3:
		_kill(i)
	await _frames(2)
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING, "and now both to the extraction")


func test_two_down_is_not_enough() -> void:
	_kill(0)
	_kill(1)
	await _frames(2)
	assert_false(objective.done)
	assert_eq(objective.sentries_left(), 1)


func test_the_clock_runs_out_and_the_mission_is_lost_with_its_reason() -> void:
	objective.time_left = 0.05
	await _frames(8)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), SilenceObjective.TOO_LATE_TEXT)


func test_an_alarm_anywhere_loses_it_at_once() -> void:
	guards[4].brain.on_alarm(Vector3.ZERO)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), SilenceObjective.ALARM_TEXT)


func test_an_alarm_after_the_last_sentry_is_down_changes_nothing() -> void:
	for i in 3:
		_kill(i)
	await _frames(2)
	guards[3].brain.on_alarm(Vector3.ZERO)
	await _frames(4)
	assert_true(objective.done)
	assert_false(objective.failed)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_the_last_sentry_dying_in_alarm_still_meets_it() -> void:
	_kill(0)
	_kill(1)
	await _frames(2)
	guards[2].brain.on_alarm(Vector3.ZERO)
	_kill(2)
	await _frames(4)
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_a_sentry_dying_in_alarm_with_others_left_loses_it() -> void:
	guards[0].brain.on_alarm(Vector3.ZERO)
	_kill(0)
	await _frames(4)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), SilenceObjective.ALARM_TEXT)


func test_a_rifle_shot_that_kills_a_sentry_brings_the_alarm_and_the_loss() -> void:
	rules.free()
	mission.free()
	await _build(true)
	# The Marksman 12 m behind the first sentry, another sentry 18 m off to hear it.
	var sentry := guards[0]
	var mark := specs[1]
	mark.global_position = sentry.global_position + sentry.global_basis.z * 12.0
	guards[1].global_position = sentry.global_position + Vector3(18, 0, 0)
	await _frames(2)
	var rifle: Ability = mark.abilities["rifle"]
	assert_true(rifle.can_use(mark, sentry), "precondition: a clear shot")
	rifle.use(mark, sentry)
	assert_false(sentry.alive, "he is down")
	_clock.engage()
	var waited := 0
	while rules.result == MissionRules.Result.RUNNING and waited < 60 * 40:
		await get_tree().physics_frame
		waited += 1
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST, "but it was a shot")
	assert_eq(rules.loss_reason(), SilenceObjective.SHOT_TEXT)


func test_a_body_found_before_the_last_is_down_loses_it() -> void:
	rules.free()
	mission.free()
	await _build(true)
	var finder := guards[3]
	var body := load(Body.SCENE).instantiate() as Body
	mission.get_node("Guards").add_child(body)
	body.global_position = finder.global_position - finder.global_basis.z * 4.0
	_clock.engage()
	var waited := 0
	while rules.result == MissionRules.Result.RUNNING and waited < 60 * 30:
		body.global_position = finder.global_position - finder.global_basis.z * 4.0
		await get_tree().physics_frame
		waited += 1
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), SilenceObjective.ALARM_TEXT)


func test_the_clock_runs_while_the_mission_does() -> void:
	await _frames(60)
	assert_almost_eq(objective.time_left, 59.0, 0.1)


func test_the_clock_stands_still_while_the_rules_say_so() -> void:
	rules.clock_running = false
	await _frames(120)
	assert_eq(objective.time_left, 60.0)
	rules.clock_running = true
	await _frames(60)
	assert_lt(objective.time_left, 59.5)


func test_the_clock_stands_still_while_the_game_is_paused() -> void:
	await _frames(2)
	var before := objective.time_left
	get_tree().paused = true
	await _frames(120)
	assert_eq(objective.time_left, before)
	get_tree().paused = false


func test_the_clock_stops_once_it_is_met_and_once_the_mission_has_ended() -> void:
	for i in 3:
		_kill(i)
	await _frames(2)
	var at := objective.time_left
	await _frames(60)
	assert_eq(objective.time_left, at, "met: no more clock")
	assert_false(objective.failed)


func test_the_words_count_sentries_and_time() -> void:
	assert_eq(objective.current_hud_text(), "Silence the sentries: 3 left. Boats in 1:00")
	_kill(0)
	objective.time_left = 59.2
	assert_eq(objective.current_hud_text(), "Silence the sentries: 2 left. Boats in 1:00")
	objective.time_left = 9.0
	assert_eq(objective.current_hud_text(), "Silence the sentries: 2 left. Boats in 0:09")


func test_the_pointer_leads_to_the_nearest_sentry_still_standing() -> void:
	specs[0].global_position = guards[1].global_position + Vector3(0, 0, 5)
	assert_almost_eq(objective.marker_position(), guards[1].global_position, Vector3.ONE * 0.01)
	_kill(1)
	assert_ne(objective.marker_position(), guards[1].global_position)
	assert_eq(objective.current_marker_name(), "Sentry")


func _saved() -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	d["version"] = SaveGame.VERSION
	return d


func test_time_left_round_trips_and_a_load_puts_it_back() -> void:
	objective.time_left = 41.5
	var d := _saved()
	assert_true(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	objective.time_left = 3.0
	mission.load_state(d)
	assert_almost_eq(objective.time_left, 41.5, 0.001)


func test_a_save_with_impossible_time_is_refused() -> void:
	for bad: Variant in [-1.0, 61.0, "soon", null]:
		var d := _saved()
		d["rules"]["objectives"][0]["time_left"] = bad
		assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission), str(bad))


func test_validator_wants_sentries_that_exist() -> void:
	objective.sentries = PackedStringArray(["Guard1", "Nobody"])
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "there is no guard called Nobody")
	objective.sentries = PackedStringArray()
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "there are no sentries to silence")
	objective.sentries = PackedStringArray(["Guard1"])
	objective.seconds = 0.0
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "the clock has no time on it")


# --- A shot is an alarm ---

func test_a_shot_fired_before_the_bank_is_quiet_loses_it_whoever_hears() -> void:
	# Far from every guard: nobody is near enough to hear it, and it is still a shot on the bank.
	var mark := specs[1]
	mark.global_position = Vector3(0, 0, 0)
	NoiseBus.emit_noise(mark.global_position, AbilityTuning.defaults().rifle_noise_radius)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), SilenceObjective.SHOT_TEXT)


func test_a_pistol_shot_loses_it_too() -> void:
	NoiseBus.emit_noise(Vector3.ZERO, AbilityTuning.defaults().pistol_noise_radius)
	await _frames(2)
	assert_eq(rules.loss_reason(), SilenceObjective.SHOT_TEXT)


func test_running_feet_are_not_a_shot() -> void:
	NoiseBus.emit_noise(Vector3.ZERO, specs[0].stats.run_noise_radius)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_a_shot_that_kills_the_last_sentry_still_meets_it() -> void:
	_kill(0)
	_kill(1)
	await _frames(2)
	NoiseBus.emit_noise(Vector3.ZERO, AbilityTuning.defaults().rifle_noise_radius)
	_kill(2)
	await _frames(2)
	assert_true(objective.done, "the dead are counted first")
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_a_shot_after_the_bank_is_quiet_changes_nothing() -> void:
	for i in 3:
		_kill(i)
	await _frames(2)
	NoiseBus.emit_noise(Vector3.ZERO, AbilityTuning.defaults().rifle_noise_radius)
	await _frames(2)
	assert_false(objective.failed)


func test_a_load_forgets_a_shot_heard_since_the_save() -> void:
	var d := _saved()
	NoiseBus.emit_noise(Vector3.ZERO, AbilityTuning.defaults().rifle_noise_radius)
	mission.load_state(d)
	await _frames(2)
	assert_false(objective.failed)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_met_stays_met_through_a_save_and_a_load() -> void:
	for i in 3:
		_kill(i)
	await _frames(2)
	var d := _saved()
	assert_true(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	mission.load_state(d)
	await _frames(2)
	assert_true(objective.done)
	assert_false(objective.failed)
