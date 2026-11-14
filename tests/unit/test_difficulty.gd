extends GutTest
## Easy, Normal and Hard scale the guards' shared numbers, and Normal puts them back.


func after_each() -> void:
	Difficulty.choose(Difficulty.Level.NORMAL)


func test_hard_is_quicker_to_alarm_and_changes_no_distance() -> void:
	Difficulty.choose(Difficulty.Level.NORMAL)
	var time := GuardTuning.defaults().far_time_to_alarm
	var far := Vision.defaults().far_range
	var wound := GuardTuning.defaults().rifle_damage
	Difficulty.choose(Difficulty.Level.HARD)
	assert_lt(GuardTuning.defaults().far_time_to_alarm, time)
	assert_gt(GuardTuning.defaults().rifle_damage, wound)
	assert_eq(Vision.defaults().far_range, far, "what is out of sight on Normal is out of sight on Hard")
	assert_eq(Vision.defaults().near_range, 6.0)


func test_easy_is_slower_and_sees_less_far_and_normal_puts_it_back() -> void:
	Difficulty.choose(Difficulty.Level.NORMAL)
	var time := GuardTuning.defaults().far_time_to_alarm
	var far := Vision.defaults().far_range
	Difficulty.choose(Difficulty.Level.EASY)
	assert_gt(GuardTuning.defaults().far_time_to_alarm, time)
	assert_lt(Vision.defaults().far_range, far)
	Difficulty.choose(Difficulty.Level.NORMAL)
	assert_eq(GuardTuning.defaults().far_time_to_alarm, time)
	assert_eq(Vision.defaults().far_range, far)


func test_a_guard_already_on_the_map_feels_the_change() -> void:
	var guard := load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(guard)
	var before := guard.brain.tuning.far_time_to_alarm
	Difficulty.choose(Difficulty.Level.HARD)
	assert_lt(guard.brain.tuning.far_time_to_alarm, before)


func test_the_briefing_goes_round_the_levels() -> void:
	var briefing := Briefing.new()
	add_child_autofree(briefing)
	assert_eq(briefing.difficulty_button.text, "Guards: Normal")
	briefing.difficulty_button.pressed.emit()
	assert_eq(briefing.difficulty_button.text, "Guards: Hard")
	briefing.difficulty_button.pressed.emit()
	assert_eq(briefing.difficulty_button.text, "Guards: Easy")
	assert_eq(Difficulty.level, Difficulty.Level.EASY)
