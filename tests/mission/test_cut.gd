extends GutTest
## Telephone lines to cut: F at the pole and four seconds standing still.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const POLE := Vector3(0, 0, -10)
const AT_POLE := Vector3(0, 0, -9.0)

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var dyn: Specialist
var mark: Specialist
var points: Array[CutPoint]
var objective: CutObjective
var input: PlayerInput
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	mission = load("res://tests/fixtures/flat_line.tscn").instantiate()
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	dyn = specs[0]
	mark = specs[1]
	rules = MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	objective = mission.objectives()[0] as CutObjective
	points = objective.point_nodes()
	var cam := IsoCamera.new()
	add_child_autofree(cam)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, specs)
	_clock.engage()


func after_each() -> void:
	_clock.release()
	get_tree().paused = false
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func _seconds(s: float) -> void:
	for i in int(roundf(s * 60.0)):
		await get_tree().physics_frame


func _f() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_F
	e.pressed = true
	input.handle_event(e)


func _start_cutting() -> void:
	dyn.global_position = AT_POLE
	_f()


func _blast(pos: Vector3) -> void:
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	add_child_autofree(charge)
	charge.global_position = pos
	charge.advance(0.1)


func _to_extraction() -> void:
	var out := mission.extraction().global_position
	dyn.global_position = Vector3(out.x, 0, out.z)
	mark.global_position = Vector3(out.x + 1.0, 0, out.z)


func _wires_shown(pole_name: String) -> int:
	var shown := 0
	for wire: MeshInstance3D in (mission.get_node("Scenery/" + pole_name) as TelegraphPole).wires():
		if wire.visible:
			shown += 1
	return shown


func test_the_fixture_is_a_sound_mission() -> void:
	assert_eq(MissionValidator.validate(mission), PackedStringArray())
	assert_eq(points.size(), 2)
	assert_eq(_wires_shown("Pole2"), 2)


func test_f_at_the_pole_and_four_seconds_still_cuts_it() -> void:
	watch_signals(points[0])
	_start_cutting()
	assert_eq(points[0].cutter, dyn)
	await _seconds(3.9)
	assert_false(points[0].cut)
	await _seconds(0.2)
	assert_true(points[0].cut)
	assert_false(points[0].usable)
	assert_null(points[0].cutter)
	assert_eq(_wires_shown("Pole2"), 0, "the wires are down")
	assert_signal_emit_count(points[0], "was_cut", 1)


func test_moving_off_stops_it_and_the_next_try_starts_from_nothing() -> void:
	_start_cutting()
	await _seconds(3.0)
	dyn.global_position = AT_POLE + Vector3(0, 0, 4)
	await _seconds(0.1)
	assert_null(points[0].cutter)
	assert_eq(points[0].progress, 0.0)
	_start_cutting()
	await _seconds(3.0)
	assert_false(points[0].cut, "three seconds again, not one")
	await _seconds(1.1)
	assert_true(points[0].cut)


func test_an_order_to_move_a_step_within_reach_stops_it_too() -> void:
	_start_cutting()
	await _seconds(2.0)
	dyn.move_to(AT_POLE + Vector3(0.6, 0, 0))
	await _seconds(0.1)
	assert_null(points[0].cutter)
	await _seconds(4.0)
	assert_false(points[0].cut)


func test_the_cutter_killed_leaves_the_line_whole() -> void:
	_start_cutting()
	await _seconds(2.0)
	dyn.take_damage(1000)
	await _seconds(3.0)
	assert_false(points[0].cut)
	assert_null(points[0].cutter)


func test_selecting_the_other_specialist_does_not_stop_it() -> void:
	_start_cutting()
	await _seconds(1.0)
	input.select(mark)
	await _seconds(3.2)
	assert_true(points[0].cut)


func test_a_second_specialist_at_the_same_pole_adds_nothing() -> void:
	watch_signals(points[0])
	_start_cutting()
	await _seconds(1.0)
	mark.global_position = AT_POLE + Vector3(0.8, 0, 0)
	assert_false(points[0].can_interact(mark), "somebody is at it")
	input.select(mark)
	_f()
	assert_eq(points[0].cutter, dyn)
	await _seconds(2.5)
	assert_false(points[0].cut, "no faster for two")
	await _seconds(0.7)
	assert_true(points[0].cut)
	assert_signal_emit_count(points[0], "was_cut", 1)


func test_it_can_be_cut_lying_down() -> void:
	dyn.set_stance(Unit.Stance.CRAWLING)
	_start_cutting()
	await _seconds(4.1)
	assert_true(points[0].cut)


func test_cutting_makes_no_noise() -> void:
	var heard := [0]
	var listen := func(_pos: Vector3, _radius: float) -> void: heard[0] += 1
	NoiseBus.noise_emitted.connect(listen)
	_start_cutting()
	await _seconds(4.2)
	NoiseBus.noise_emitted.disconnect(listen)
	assert_true(points[0].cut)
	assert_eq(heard[0], 0)


func test_both_cut_and_the_objective_is_met_and_says_so_once() -> void:
	var said: Array = []
	rules.objective_done.connect(func(o: Objective) -> void: said.append(o.done_text))
	points[0].set_cut(true)
	await _seconds(0.1)
	assert_false(objective.done)
	points[1].set_cut(true)
	await _seconds(0.2)
	assert_true(objective.done)
	assert_eq(said, ["The lines are cut"])


func test_the_words_count_what_is_left() -> void:
	assert_eq(objective.current_hud_text(), "Cut the telephone lines: 2 left")
	assert_almost_eq(objective.marker_position(), points[0].global_position, Vector3.ONE * 0.01)
	points[0].set_cut(true)
	assert_eq(objective.current_hud_text(), "Cut the telephone lines: 1 left")
	assert_almost_eq(objective.marker_position(), points[1].global_position, Vector3.ONE * 0.01)


func test_a_blast_beside_a_pole_does_not_cut_it() -> void:
	_blast(POLE + Vector3(0.5, 0, 0.5))
	await _seconds(0.2)
	assert_false(points[0].cut)
	assert_eq(_wires_shown("Pole2"), 2)
	assert_false((mission.objectives()[1] as DestroyObjective).done, "nor is that the store")


func test_lines_then_store_wins() -> void:
	points[0].set_cut(true)
	points[1].set_cut(true)
	await _seconds(0.1)
	_blast((mission.get_node("BridgeTarget") as Node3D).global_position)
	_to_extraction()
	await _seconds(0.3)
	assert_eq(rules.result, MissionRules.Result.WON)


func test_store_then_lines_wins() -> void:
	_blast((mission.get_node("BridgeTarget") as Node3D).global_position)
	await _seconds(0.1)
	assert_eq(rules.current_objective(), objective, "the lines are still to do")
	points[1].set_cut(true)
	points[0].set_cut(true)
	_to_extraction()
	await _seconds(0.3)
	assert_eq(rules.result, MissionRules.Result.WON)


func test_one_without_the_other_is_not_a_win() -> void:
	points[0].set_cut(true)
	points[1].set_cut(true)
	_to_extraction()
	await _seconds(0.3)
	assert_eq(rules.result, MissionRules.Result.RUNNING, "the store stands")
	assert_eq(rules.current_objective(), mission.objectives()[1])


func _saved() -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	d["version"] = SaveGame.VERSION
	return d


func test_a_load_in_the_middle_of_cutting_leaves_it_whole_and_idle() -> void:
	var before := _saved()
	_start_cutting()
	await _seconds(2.0)
	mission.load_state(before)
	assert_null(points[0].cutter)
	assert_eq(points[0].progress, 0.0)
	assert_false(points[0].cut)
	await _seconds(4.5)
	assert_false(points[0].cut, "nobody is at it after the load")


func test_cut_lines_stay_cut_through_a_save_and_a_load() -> void:
	points[0].set_cut(true)
	var d := _saved()
	assert_eq(d["rules"]["objectives"][0]["cut"], [true, false])
	assert_true(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	mission.load_state(d)
	assert_true(points[0].cut)
	assert_false(points[1].cut)
	assert_eq(_wires_shown("Pole2"), 0)


func test_a_load_from_before_puts_a_cut_line_back_up() -> void:
	var before := _saved()
	points[0].set_cut(true)
	mission.load_state(before)
	assert_false(points[0].cut)
	assert_true(points[0].usable)
	assert_eq(_wires_shown("Pole2"), 2)


func test_a_save_with_the_wrong_number_of_lines_is_refused() -> void:
	var d := _saved()
	d["rules"]["objectives"][0]["cut"].append(true)
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	d = _saved()
	d["rules"]["objectives"][0]["cut"][0] = 1
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	d = _saved()
	d["rules"]["objectives"][0].erase("cut")
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))


func test_validator_wants_points_that_can_be_stood_at() -> void:
	points[1].global_position = Vector3(300, 0, 300)
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "nobody can stand at Cut2")
	objective.points = [NodePath("Cut1"), NodePath("Nowhere")]
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "there is no cut point at Nowhere")
	objective.points = []
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "there is nothing to cut")


func test_f_pressed_on_the_move_stops_him_there_and_the_cut_goes_on() -> void:
	dyn.global_position = AT_POLE + Vector3(0.9, 0, 0.6)
	dyn.move_to(AT_POLE)
	await _seconds(0.05)
	assert_true(dyn.is_moving(), "precondition: still walking up to it")
	_f()
	assert_eq(points[0].cutter, dyn)
	assert_false(dyn.is_moving(), "F at the pole halts him")
	await _seconds(4.1)
	assert_true(points[0].cut, "he stood still as told, and it is cut")
