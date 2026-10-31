extends GutTest

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var results: Array = []
var blown := 0


func before_each() -> void:
	results.clear()
	blown = 0
	mission = load("res://scenes/missions/bridge.tscn").instantiate()
	# Live guards would shoot the specialists; these tests are about the rules.
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	rules = MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	rules.result_changed.connect(func(r: int) -> void: results.append(r))
	rules.bridge_blown.connect(func() -> void: blown += 1)


func after_each() -> void:
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func _frames(n := 6) -> void:
	for i in n:
		await get_tree().physics_frame


func _blast(pos: Vector3) -> void:
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	add_child_autofree(charge)
	charge.global_position = pos
	charge.advance(0.1)


func _blow_bridge() -> void:
	_blast(mission.bridge_target().global_position)


func _to_extraction(s: Specialist) -> void:
	s.global_position = mission.extraction().global_position + Vector3(0, -1.5, 0)


func test_spawn_specialists_at_spawns_with_nav() -> void:
	assert_eq(specs.size(), 2)
	var spawns := mission.specialist_spawns()
	for i in 2:
		assert_almost_eq(specs[i].global_position, spawns[i].global_position, Vector3.ONE * 0.001)
		assert_true(specs[i].is_in_group(Specialist.GROUP))
	assert_true(specs[0].has_ability("charge"))
	assert_true(specs[1].has_ability("rifle"))
	specs[0].move_to(specs[0].global_position + Vector3(4, 0, 0))
	await _frames(30)
	assert_gt(specs[0].global_position.x, spawns[0].global_position.x + 1.0, "walks on the navmesh")


func test_win_needs_bridge_and_both_at_extraction() -> void:
	_blow_bridge()
	_to_extraction(specs[0])
	await _frames()
	assert_eq(rules.result, MissionRules.Result.RUNNING, "one specialist is not enough")
	_to_extraction(specs[1])
	await _frames()
	assert_eq(rules.result, MissionRules.Result.WON)
	assert_eq(results, [MissionRules.Result.WON])


func test_extraction_before_bridge_does_not_win() -> void:
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames()
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_false(rules.bridge_destroyed)


func test_win_after_bridge_when_already_waiting() -> void:
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames()
	_blow_bridge()
	await _frames()
	assert_eq(rules.result, MissionRules.Result.WON)


func test_leaving_extraction_clears_presence() -> void:
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames()
	assert_true(rules.at_extraction(specs[1]))
	specs[1].global_position = mission.specialist_spawns()[1].global_position
	await _frames()
	assert_false(rules.at_extraction(specs[1]))
	assert_true(rules.at_extraction(specs[0]))
	_blow_bridge()
	await _frames()
	assert_eq(rules.result, MissionRules.Result.RUNNING, "the one who left is missing")


func test_specialist_death_loses() -> void:
	specs[1].take_damage(1000)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(results, [MissionRules.Result.LOST])


func test_dead_specialist_at_extraction_does_not_count() -> void:
	_blow_bridge()
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	specs[1].alive = false  # dead without the died signal: still must not count
	await _frames()
	assert_ne(rules.result, MissionRules.Result.WON)


func test_death_and_bridge_same_frame_is_loss() -> void:
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames()
	_blow_bridge()
	specs[0].take_damage(1000)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_true(rules.bridge_destroyed)


func test_charge_far_from_bridge_does_not_count() -> void:
	_blast(mission.bridge_target().global_position + Vector3(20, 0, 0))
	await _frames(2)
	assert_false(rules.bridge_destroyed)
	assert_eq(blown, 0)


func test_charge_within_blast_distance_counts_once() -> void:
	_blast(mission.bridge_target().global_position + Vector3(7.5, 0, 0))
	_blow_bridge()
	assert_true(rules.bridge_destroyed)
	assert_eq(blown, 1, "bridge_blown fires once")


func test_result_is_final_after_won_or_lost() -> void:
	specs[0].take_damage(1000)
	await _frames(2)
	assert_eq(rules.result, MissionRules.Result.LOST)
	_blow_bridge()
	_to_extraction(specs[1])
	await _frames()
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(results, [MissionRules.Result.LOST])


func test_won_is_final() -> void:
	_blow_bridge()
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames()
	assert_eq(rules.result, MissionRules.Result.WON)
	specs[0].take_damage(1000)
	await _frames()
	assert_eq(rules.result, MissionRules.Result.WON)


func test_alarm_level_counts_living_guards_in_alarm() -> void:
	var guards := mission.guards()
	assert_eq(rules.alarm_level, 0)
	guards[0].brain.on_alarm(Vector3.ZERO)
	guards[1].brain.on_alarm(Vector3.ZERO)
	assert_eq(rules.alarm_level, 2)
	guards[1].take_damage(1000)
	assert_eq(rules.alarm_level, 1, "dead guards do not count")


func test_broken_bridge_swaps_deck_and_navmesh() -> void:
	var west := mission.specialist_spawns()[0].global_position
	var east := mission.extraction().global_position
	assert_true(_reaches(west, east), "reachable over the intact bridge")
	_blow_bridge()
	await _frames(2)
	assert_null(mission.get_node_or_null("Nav/BridgeDeck"))
	assert_not_null(mission.get_node_or_null("Nav/BridgeBroken"))
	assert_false(_reaches(west, east), "the gorge is open")
	var east_spot := Vector3(20, 0, 10)
	assert_true(_reaches(east, east_spot), "the extraction bank still navigates")
	specs[0].global_position = Vector3(12, 0, 0)
	specs[0].move_to(east)
	await _frames(60)
	assert_gt(specs[0].global_position.x, 13.5, "walks east on the rebaked navmesh")


func test_save_and_load_state_is_json_safe() -> void:
	_blow_bridge()
	specs[0].take_damage(1000)
	await _frames(2)
	var d := rules.save_state()
	var copy: Dictionary = JSON.parse_string(JSON.stringify(d))
	assert_eq(int(copy["result"]), MissionRules.Result.LOST)
	assert_true(copy["bridge_destroyed"])

	var fresh: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	fresh.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(fresh)
	await get_tree().process_frame
	fresh.build_nav()
	var fresh_specs := fresh.spawn_specialists()
	var other := MissionRules.new()
	add_child_autofree(other)
	other.setup(fresh, fresh_specs)
	other.load_state(copy)
	assert_eq(other.result, MissionRules.Result.LOST)
	assert_true(other.bridge_destroyed)
	await get_tree().process_frame
	assert_null(fresh.get_node_or_null("Nav/BridgeDeck"), "broken deck restored")
	assert_not_null(fresh.get_node_or_null("Nav/BridgeBroken"))
	assert_false(_reaches_in(fresh, fresh.specialist_spawns()[0].global_position, fresh.extraction().global_position))


func test_extraction_area_sees_units_layer() -> void:
	var area := mission.extraction()
	assert_true(area.monitoring)
	assert_ne(area.collision_mask & Unit.LAYER_UNITS, 0)


func _reaches(from: Vector3, to: Vector3) -> bool:
	return _reaches_in(mission, from, to)


func _reaches_in(m: Mission, from: Vector3, to: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(m.nav_map(), from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= 1.0
