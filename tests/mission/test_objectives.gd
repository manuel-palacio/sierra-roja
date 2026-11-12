extends GutTest
## What every objective does, and the one that is met by blowing something up.

var mission: Mission
var objective: DestroyObjective


func before_each() -> void:
	mission = load("res://tests/fixtures/flat_bridge.tscn").instantiate()
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	objective = DestroyObjective.new()
	objective.name = "Blow"
	objective.target = NodePath("BridgeTarget")
	mission.add_child(objective)
	objective.setup(mission, null)
	watch_signals(objective)


func _target() -> Vector3:
	return (mission.get_node("BridgeTarget") as Node3D).global_position


func test_base_objective_completes_once() -> void:
	var o: Objective = autofree(Objective.new())
	watch_signals(o)
	o.complete()
	o.complete()
	assert_true(o.done)
	assert_signal_emit_count(o, "completed", 1)


func test_base_state_round_trips() -> void:
	var o: Objective = autofree(Objective.new())
	o.complete()
	var p: Objective = autofree(Objective.new())
	assert_true(p.state_ok(o.save_state()))
	p.load_state(o.save_state())
	assert_true(p.done)
	assert_false(p.state_ok({"done": 1}))


func test_destroy_done_by_a_charge_in_range() -> void:
	objective.on_detonated(_target() + Vector3(7.9, 0, 0))
	assert_true(objective.done)
	assert_signal_emit_count(objective, "completed", 1)


func test_destroy_not_done_out_of_range_and_says_so() -> void:
	objective.on_detonated(_target() + Vector3(8.1, 0, 0))
	assert_false(objective.done)
	assert_signal_emitted(objective, "charge_too_far")


func test_destroy_validate_reports_missing_target() -> void:
	assert_eq(objective.validate(mission, mission.nav_map(), Vector3(-30, 0, 0)).size(), 0, "sound as built")
	objective.target = NodePath("Nowhere")
	assert_eq(objective.validate(mission, mission.nav_map(), Vector3(-30, 0, 0)).size(), 1)


func test_destroy_marks_its_target() -> void:
	assert_almost_eq(objective.marker_position(), _target(), Vector3.ONE * 0.001)
