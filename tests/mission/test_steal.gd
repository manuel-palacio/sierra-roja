extends GutTest
## Orders on a table: taking them, putting them down, and what winning takes.

const ITEM := Vector3(10, 0, 0)
const BESIDE := Vector3(10, 0, 1.2)

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var dyn: Specialist
var mark: Specialist
var item: Carryable
var objective: StealObjective
var input: PlayerInput
var refusals: Array = []


func before_each() -> void:
	refusals.clear()
	mission = load("res://tests/fixtures/flat_post.tscn").instantiate()
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
	item = mission.get_node("Item") as Carryable
	objective = mission.objectives()[0] as StealObjective
	var cam := IsoCamera.new()
	add_child_autofree(cam)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, specs)
	input.order_refused.connect(func(r: String) -> void: refusals.append(r))


func after_each() -> void:
	get_tree().paused = false
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()


func _frames(n := 6) -> void:
	for i in n:
		await get_tree().physics_frame


func _f() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_F
	e.pressed = true
	input.handle_event(e)


func _take() -> void:
	dyn.global_position = BESIDE
	_f()


func _to_extraction(unit: Node3D, offset := 0.0) -> void:
	var out := mission.extraction().global_position
	unit.global_position = Vector3(out.x + offset, 0, out.z)


func _body_at(pos: Vector3) -> Body:
	var body := load(Body.SCENE).instantiate() as Body
	mission.get_node("Guards").add_child(body)
	body.global_position = pos
	return body


func test_the_fixture_is_a_sound_mission() -> void:
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_f_next_to_it_takes_it() -> void:
	_take()
	assert_eq(item.carrier, dyn)
	assert_eq(dyn.holding, item)
	assert_false(item.usable)
	assert_false(item.visible, "gone from the table")


func test_it_cannot_be_taken_from_beyond_reach() -> void:
	dyn.global_position = ITEM + Vector3(0, 0, 2.2)
	_f()
	assert_null(item.carrier)


func test_the_marksman_can_take_it_too() -> void:
	mark.global_position = BESIDE
	input.select(mark)
	_f()
	assert_eq(item.carrier, mark)


func test_f_again_puts_it_down_at_their_feet() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	_f()
	assert_null(item.carrier)
	assert_null(dyn.holding)
	assert_true(item.usable)
	assert_true(item.visible)
	assert_almost_eq(item.global_position, Vector3(-5, 0, 6), Vector3.ONE * 0.05)


func test_it_can_be_taken_up_again_by_the_other() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	_f()
	dyn.global_position = Vector3(-20, 0, 6)
	mark.global_position = Vector3(-5, 0, 7)
	input.select(mark)
	_f()
	assert_eq(item.carrier, mark)


func test_the_carrier_can_still_crawl_and_use_the_knife() -> void:
	var guard := mission.guards()[0]
	guard.global_position = BESIDE + Vector3(0.8, 0, 0)
	await _frames(2)
	dyn.global_position = BESIDE
	var knife: Ability = dyn.abilities["knife"]
	var could := knife.can_use(dyn, guard)
	_f()
	assert_eq(dyn.holding, item)
	dyn.set_stance(Unit.Stance.CRAWLING)
	assert_eq(dyn.stance, Unit.Stance.CRAWLING)
	assert_true(could, "precondition: the guard is in reach of the knife")
	assert_true(knife.can_use(dyn, guard))
	knife.use(dyn, guard)
	assert_false(guard.alive)


func test_the_carrier_cannot_lift_a_body_and_f_puts_the_orders_down_instead() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	var body := _body_at(Vector3(-5, 0, 6.5))
	_f()
	assert_null(dyn.carrying, "no hands for a body")
	assert_null(dyn.holding, "the orders went down")
	assert_null(body.carried_by)


func test_with_empty_hands_the_next_f_lifts_the_body() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	var body := _body_at(Vector3(-5, 0, 6.5))
	_f()
	assert_null(dyn.holding, "precondition: the orders are at his feet, nearer than the body")
	_f()
	assert_eq(dyn.carrying, body, "he put them down to have his hands free for this")
	assert_null(item.carrier)


func test_with_no_body_about_the_next_f_takes_the_orders_up_again() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	_f()
	_f()
	assert_eq(item.carrier, dyn)


func test_after_he_has_moved_f_takes_the_orders_even_beside_a_body() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	var body := _body_at(Vector3(-5, 0, 6.5))
	_f()
	input.move_ordered.emit(Vector3(-5, 0, 6.2), false)  # any order to move: he has moved on
	_f()
	assert_eq(item.carrier, dyn, "the thing in reach comes first again")
	assert_null(body.carried_by)


func test_the_body_put_down_again_the_orders_can_be_taken() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	var body := _body_at(Vector3(-5, 0, 6.5))
	_f()
	_f()
	assert_eq(dyn.carrying, body)
	_f()
	assert_null(dyn.carrying, "the body goes down")
	_f()
	assert_eq(item.carrier, dyn)


func test_the_orders_ride_on_the_carriers_back_and_go_down_with_him() -> void:
	_take()
	var held := dyn.find_children("Held", "MeshInstance3D", true, false)
	assert_eq(held.size(), 1)
	var attachment := held[0].get_parent() as BoneAttachment3D
	assert_not_null(attachment, "on a bone of his back, so they lie down when he does")
	assert_true(dyn.get_node("Model").is_ancestor_of(attachment))
	_f()
	await get_tree().process_frame
	assert_eq(dyn.find_children("Held", "MeshInstance3D", true, false).size(), 0, "gone from his back when put down")


func test_the_huds_carry_button_does_not_lift_a_body_either() -> void:
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	var body := _body_at(Vector3(-5, 0, 6.5))
	assert_false((dyn.abilities["carry"] as Ability).can_use(dyn, body))
	input.arm_ability(&"carry")
	assert_null(dyn.carrying)
	assert_null(dyn.holding, "it puts the orders down, as the key does")


func test_someone_carrying_a_body_cannot_take_it() -> void:
	var body := _body_at(BESIDE)
	dyn.global_position = BESIDE
	dyn.pick_up(body)
	assert_false(item.can_interact(dyn))
	item.interact(dyn)
	assert_null(item.carrier)


func test_the_carrier_dying_drops_it_where_they_fell() -> void:
	_take()
	dyn.global_position = Vector3(-8, 0, 3)
	dyn.take_damage(1000)
	assert_null(item.carrier)
	assert_true(item.usable)
	assert_almost_eq(item.global_position, Vector3(-8, 0, 3), Vector3.ONE * 0.05)


func test_carried_to_the_extraction_with_both_there_the_mission_is_won() -> void:
	_take()
	_to_extraction(dyn)
	_to_extraction(mark, 1.0)
	await _frames()
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.WON)


func test_the_carrier_there_without_the_other_is_not_a_win() -> void:
	_take()
	_to_extraction(dyn)
	await _frames()
	assert_true(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_lying_inside_the_extraction_it_is_not_a_win() -> void:
	_take()
	var out := mission.extraction().global_position
	item.lie_at(Vector3(out.x, 0, out.z))
	_to_extraction(mark, 1.0)
	dyn.global_position = Vector3(out.x - 1.0, 0, out.z)
	await _frames()
	assert_false(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_having_held_it_once_is_not_enough() -> void:
	_take()
	_f()  # put down again, by the table
	_to_extraction(dyn)
	_to_extraction(mark, 1.0)
	await _frames()
	assert_false(objective.done)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_the_words_and_the_pointer_follow_it() -> void:
	assert_eq(objective.current_hud_text(), "Take the orders")
	assert_eq(objective.current_marker_name(), "Command post")
	assert_almost_eq(objective.marker_position(), item.global_position, Vector3.ONE * 0.01)
	_take()
	assert_eq(objective.current_hud_text(), "Bring the orders out")
	assert_eq(objective.current_marker_name(), "Extraction")
	assert_almost_eq(objective.marker_position().z, mission.extraction().global_position.z, 0.01)
	dyn.global_position = Vector3(-5, 0, 6)
	_f()
	assert_eq(objective.current_hud_text(), "Take the orders")
	assert_almost_eq(objective.marker_position(), Vector3(-5, 0, 6), Vector3.ONE * 0.05)


func test_validator_wants_it_within_reach_of_somewhere_to_stand() -> void:
	item.global_position = Vector3(200, 0, 200)
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "nobody can stand within reach of it")
	objective.item = NodePath("Nothing")
	assert_string_contains("\n".join(MissionValidator.validate(mission)), "there is nothing to take")


func _saved() -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(mission.save_state()))
	d["version"] = SaveGame.VERSION
	return d


func test_state_round_trips_through_json() -> void:
	_take()
	var d := _saved()
	assert_eq(d["rules"]["objectives"][0]["carrier"], String(dyn.name))
	assert_true(SaveSchema.is_valid(d, SaveGame.VERSION, mission))


func test_load_from_before_it_was_taken_puts_it_back() -> void:
	var before := _saved()
	_take()
	dyn.global_position = Vector3(-5, 0, 6)
	mission.load_state(before)
	assert_null(item.carrier)
	assert_null(dyn.holding)
	assert_true(item.usable)
	assert_almost_eq(item.global_position, ITEM, Vector3.ONE * 0.01)
	assert_eq(dyn.find_children("Held", "MeshInstance3D", false, false).filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 0, "nothing left on his back")


func test_load_from_while_carried_puts_it_back_in_hand() -> void:
	_take()
	var carried := _saved()
	_f()
	assert_null(item.carrier, "precondition: put down")
	mission.load_state(carried)
	assert_eq(item.carrier, dyn)
	assert_eq(dyn.holding, item)
	assert_false(item.usable)


func test_load_hands_it_from_one_to_the_other() -> void:
	mark.global_position = BESIDE
	input.select(mark)
	_f()
	var with_marksman := _saved()
	_f()
	input.select(dyn)
	_take()
	mission.load_state(with_marksman)
	assert_eq(item.carrier, mark)
	assert_null(dyn.holding)
	assert_eq(mark.holding, item)


func test_a_save_naming_a_dead_or_unknown_carrier_is_refused() -> void:
	_take()
	var d := _saved()
	d["rules"]["objectives"][0]["carrier"] = "Nobody"
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	d = _saved()
	for s: Dictionary in d["specialists"]:
		if s["id"] == String(dyn.name):
			s["hp"] = 0
			s["alive"] = false
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
	d = _saved()
	d["rules"]["objectives"][0]["pos"] = [0, "x", 0]
	assert_false(SaveSchema.is_valid(d, SaveGame.VERSION, mission))
