extends GutTest
## A prisoner in a locked cell: the door, his following, and what winning and losing take.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const CELL := Vector3(10, 0, 0)
const AT_DOOR := Vector3(10, 0, 3.2)

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var dyn: Specialist
var mark: Specialist
var prisoner: Prisoner
var door: CellDoor
var objective: RescueObjective
var input: PlayerInput
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	mission = load("res://tests/fixtures/flat_cell.tscn").instantiate()
	# Live guards would shoot; each test that wants one wakes it.
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
	prisoner = mission.get_node("Prisoner") as Prisoner
	door = mission.get_node("CellDoor") as CellDoor
	objective = mission.objectives()[0] as RescueObjective
	var cam := IsoCamera.new()
	add_child_autofree(cam)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, specs)


func after_each() -> void:
	_clock.release()
	get_tree().paused = false
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func _frames(n := 6) -> void:
	for i in n:
		await get_tree().physics_frame


## Lets a rebake asked for this frame happen.
func _rebaked() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(2)


func _reaches(from: Vector3, to: Vector3) -> bool:
	return MissionValidator.reaches(mission.nav_map(), from, to)


func _f() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_F
	e.pressed = true
	input.handle_event(e)


func _open_the_door() -> void:
	dyn.global_position = AT_DOOR
	_f()
	await _rebaked()


func _to_extraction(unit: Unit, offset := 0.0) -> void:
	var out := mission.extraction().global_position
	unit.global_position = Vector3(out.x + offset, 0, out.z)


func _blast(pos: Vector3) -> void:
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	add_child_autofree(charge)
	charge.global_position = pos
	charge.advance(0.1)


func test_the_fixture_is_a_sound_mission() -> void:
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_prisoner_cannot_be_reached_while_the_door_is_shut() -> void:
	assert_false(_reaches(dyn.global_position, CELL))
	assert_true(_reaches(dyn.global_position, door.stand_point()))


func test_f_at_the_door_opens_it_and_he_follows() -> void:
	await _open_the_door()
	assert_true(door.open)
	assert_eq(prisoner.leader, dyn)
	assert_true(_reaches(dyn.global_position, CELL), "the way in exists now")


func test_door_cannot_be_opened_from_beyond_reach() -> void:
	dyn.global_position = AT_DOOR + Vector3(0, 0, 1.0)
	_f()
	assert_false(door.open)
	assert_null(prisoner.leader)


func test_door_cannot_be_opened_twice_or_by_a_second_leader() -> void:
	await _open_the_door()
	mark.global_position = AT_DOOR
	input.select(mark)
	_f()
	assert_eq(prisoner.leader, dyn, "he stays with whoever freed him")


func test_he_matches_the_leaders_stance() -> void:
	await _open_the_door()
	dyn.set_stance(Unit.Stance.CRAWLING)
	await _frames(2)
	assert_eq(prisoner.stance, Unit.Stance.CRAWLING)
	dyn.set_stance(Unit.Stance.STANDING)
	await _frames(2)
	assert_eq(prisoner.stance, Unit.Stance.STANDING)


func test_he_keeps_up_over_twenty_metres() -> void:
	await _open_the_door()
	_clock.engage()
	dyn.move_to(AT_DOOR + Vector3(-20, 0, 2))
	var waited := 0
	while dyn._moving and waited < 1200:
		await get_tree().physics_frame
		waited += 1
	await _frames(240)
	assert_lt(waited, 1200, "the leader arrived")
	assert_lt(prisoner.global_position.distance_to(dyn.global_position), Prisoner.CATCH_UP + 0.5)


func test_guards_ignore_him_in_the_cell_and_see_him_once_out() -> void:
	var guard := mission.guards()[0]
	guard.global_position = Vector3(10, 0, 9)
	guard.face(CELL)
	await _frames(2)
	assert_eq(guard._strongest_target()["zone"], Vision.Zone.NONE, "held, he is nobody's business")
	await _open_the_door()
	dyn.global_position = Vector3(-20, 0, 20)  # out of the guard's sight; he has not moved yet
	prisoner.stop()
	prisoner.global_position = Vector3(10, 0, 4)
	await _frames(2)
	var seen := guard._strongest_target()
	assert_ne(seen["zone"], Vision.Zone.NONE)
	assert_eq(seen["specialist"], prisoner)


func test_he_reaches_the_extraction_with_both_and_the_mission_is_won() -> void:
	await _open_the_door()
	_to_extraction(dyn)
	_to_extraction(mark, 1.0)
	_to_extraction(prisoner, -1.0)
	await _frames()
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.WON)


func test_he_alone_at_the_extraction_is_not_a_win() -> void:
	await _open_the_door()
	prisoner.leader = null  # stays where he is put
	_to_extraction(prisoner)
	await _frames()
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_both_at_the_extraction_without_him_is_not_a_win() -> void:
	_to_extraction(dyn)
	_to_extraction(mark, 1.0)
	await _frames()
	assert_false(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_a_charge_that_kills_him_loses_with_his_reason() -> void:
	_blast(CELL + Vector3(0, 0, -4))
	await _frames(2)
	assert_false(prisoner.alive, "the cell wall does not save him")
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), RescueObjective.KILLED_TEXT)


func test_a_charge_far_from_him_says_nothing_about_a_target() -> void:
	var missed := [0]
	rules.charge_too_far.connect(func() -> void: missed[0] += 1)
	_blast(Vector3(25, 0, 20))
	await _frames(2)
	assert_eq(missed[0], 0)
	assert_true(prisoner.alive)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_validator_wants_a_door_that_can_be_stood_at() -> void:
	door.global_position = Vector3(10, 0, 0.5)  # its outside is now the inside of the cell
	var text := "\n".join(MissionValidator.validate(mission))
	assert_string_contains(text, "nobody can stand at the cell door")


func test_validator_wants_a_prisoner_and_a_door() -> void:
	objective.prisoner = NodePath("Nobody")
	objective.door = NodePath("Nothing")
	var text := "\n".join(MissionValidator.validate(mission))
	assert_string_contains(text, "there is no prisoner")
	assert_string_contains(text, "the cell has no door")


func test_the_words_change_once_the_door_is_open() -> void:
	assert_eq(objective.current_hud_text(), "Free the officer")
	assert_eq(objective.current_marker_name(), "Cells")
	assert_almost_eq(objective.marker_position(), door.global_position, Vector3.ONE * 0.01)
	await _open_the_door()
	assert_eq(objective.current_hud_text(), objective.escort_text)
	assert_eq(objective.current_marker_name(), "Extraction")
	assert_almost_eq(objective.marker_position().x, mission.extraction().global_position.x, 0.01)


func test_state_round_trips_through_json() -> void:
	await _open_the_door()
	var d: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	assert_true(d["rules"]["objectives"][0]["door_open"])
	assert_eq(d["prisoners"][0]["leader"], String(dyn.name))
	assert_true(SaveSchema.is_valid(_with_version(d), SaveGame.VERSION, mission))
	d["prisoners"][0]["leader"] = "Nobody"
	assert_false(SaveSchema.is_valid(_with_version(d), SaveGame.VERSION, mission))


func _with_version(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out["version"] = SaveGame.VERSION
	return out


func test_load_from_before_the_door_shuts_it_again() -> void:
	var before: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	await _open_the_door()
	dyn.global_position = AT_DOOR + Vector3(-5, 0, 2)
	prisoner.global_position = AT_DOOR + Vector3(-3, 0, 2)
	mission.load_state(before)
	await _rebaked()
	assert_false(door.open)
	assert_null(prisoner.leader)
	assert_false(prisoner.is_in_group(Unit.HUNTED))
	assert_almost_eq(prisoner.global_position, CELL, Vector3.ONE * 0.1)
	assert_false(_reaches(dyn.global_position, CELL), "and the cell is shut off again")
	assert_eq(rules.result, MissionRules.Result.RUNNING, "nobody is cut off by the door shutting")
	dyn.global_position = AT_DOOR
	_f()
	assert_true(door.open, "and it can be opened again")


func test_load_from_after_keeps_him_following() -> void:
	await _open_the_door()
	var after: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	prisoner.follow(null)
	mission.load_state(after)
	await _rebaked()
	assert_true(door.open)
	assert_eq(prisoner.leader, dyn)
	assert_true(prisoner.is_in_group(Unit.HUNTED))
