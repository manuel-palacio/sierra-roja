extends GutTest
## The score of a mission: time, kills, alarms and loads, the name it earns, and the best kept.

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]


func before_each() -> void:
	Campaign.reset()
	mission = load("res://tests/fixtures/flat_bridge.tscn").instantiate()
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	rules = MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	rules.set_physics_process(false)


func after_each() -> void:
	Campaign.reset()
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()


func test_time_runs_only_while_the_mission_does() -> void:
	rules.keep_score(2.5)
	rules.clock_running = false
	rules.keep_score(10.0)
	assert_almost_eq(rules.score.seconds, 2.5, 0.001, "not behind the briefing")
	rules.clock_running = true
	rules.result = MissionRules.Result.WON
	rules.keep_score(10.0)
	assert_almost_eq(rules.score.seconds, 2.5, 0.001, "nor once it has ended")


func test_a_guard_killed_is_counted_and_spoils_the_ghost() -> void:
	assert_eq(rules.score.rating(), MissionScore.Rating.GHOST)
	mission.guards()[0].take_damage(1000)
	assert_eq(rules.score.kills, 1)
	assert_eq(rules.score.rating(), MissionScore.Rating.UNSEEN)


func test_an_alarm_is_counted_once_from_start_to_end() -> void:
	var guard := mission.guards()[0]
	guard.brain.on_alarm(Vector3.ZERO)
	rules.keep_score(0.1)
	rules.keep_score(0.1)
	assert_eq(rules.score.alarms, 1)
	assert_eq(rules.score.rating(), MissionScore.Rating.DONE)
	guard.brain.load_state(GuardBrain.new().save_state())
	rules.keep_score(0.1)
	guard.brain.on_alarm(Vector3.ZERO)
	rules.keep_score(0.1)
	assert_eq(rules.score.alarms, 2, "a second alarm is a second alarm")


func test_a_load_puts_the_score_back_and_counts_itself() -> void:
	rules.keep_score(5.0)
	var saved := rules.save_state()
	rules.keep_score(20.0)
	mission.guards()[0].take_damage(1000)
	rules.load_state(saved)
	assert_almost_eq(rules.score.seconds, 5.0, 0.001)
	assert_eq(rules.score.kills, 0)
	assert_eq(rules.score.loads, 1)
	rules.load_state(saved)
	assert_eq(rules.score.loads, 2)


func test_the_best_win_is_kept_and_only_a_better_one_replaces_it() -> void:
	var slow_ghost := MissionScore.from_dict({ "seconds": 300.0, "kills": 0, "alarms": 0, "loads": 0 })
	var fast_loud := MissionScore.from_dict({ "seconds": 60.0, "kills": 4, "alarms": 2, "loads": 0 })
	var fast_ghost := MissionScore.from_dict({ "seconds": 200.0, "kills": 0, "alarms": 0, "loads": 3 })
	assert_true(Campaign.record("guadarrama", fast_loud))
	assert_true(Campaign.record("guadarrama", slow_ghost), "a ghost beats any time with an alarm")
	assert_false(Campaign.record("guadarrama", fast_loud))
	assert_true(Campaign.record("guadarrama", fast_ghost))
	var text := Campaign.stored_scores()
	Campaign.reset()
	assert_null(Campaign.best("guadarrama"))
	Campaign.load_scores_from(text)
	assert_almost_eq(Campaign.best("guadarrama").seconds, 200.0, 0.001)
	Campaign.load_scores_from("{\"guadarrama\": {\"seconds\": -1}, \"nowhere\": {}}")
	assert_null(Campaign.best("guadarrama"), "rubbish counts for nothing")


func test_the_end_screen_tells_the_score_of_a_win() -> void:
	var screen := EndScreen.new()
	add_child_autofree(screen)
	var score := MissionScore.from_dict({ "seconds": 247.0, "kills": 2, "alarms": 0, "loads": 1 })
	screen.show_result(MissionRules.Result.WON, "", score, true)
	assert_true(screen.score_label.visible)
	assert_eq(screen.score_label.text, "Unseen  ·  Time 4:07  ·  Guards killed 2  ·  Alarms 0  ·  Loads 1  ·  Best yet")
	screen.show_result(MissionRules.Result.LOST, "A specialist was killed", score)
	assert_false(screen.score_label.visible)
