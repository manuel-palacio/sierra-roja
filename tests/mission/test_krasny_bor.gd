extends GutTest
## Krasny Bor: a sound map in snow before dawn, three lines to cut and a store to destroy, and the
## end of the campaign.

const SCENE := "res://scenes/missions/krasny_bor.tscn"
const BridgeBot := preload("res://tests/run/bridge_bot.gd")

var mission: Mission
var _clock := BridgeBot.FastClock.new()


func after_each() -> void:
	_clock.release()
	get_tree().paused = false
	Missions.current = 0
	Briefing.seen = false
	Campaign.reset()
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func _built(live_guards := false) -> Mission:
	mission = load(SCENE).instantiate()
	if not live_guards:
		mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().physics_frame
	mission.build_nav()
	await wait_physics_frames(2)
	return mission


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z), p.z)


func _reaches(from: Vector3, to: Vector3) -> bool:
	return MissionValidator.reaches(mission.nav_map(), _on_ground(from), _on_ground(to))


func _rules() -> MissionRules:
	var specs := mission.spawn_specialists()
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	return rules


func _blast(pos: Vector3) -> void:
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	add_child_autofree(charge)
	charge.global_position = _on_ground(pos)
	charge.advance(0.1)


func test_validator_passes() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


func test_it_is_snow_before_dawn_with_eight_guards_in_blue_and_a_searchlight() -> void:
	await _built()
	assert_eq(mission.season, &"snow")
	assert_true(mission.night)
	assert_eq(mission.light, &"predawn")
	assert_true(mission.snowfall)
	assert_eq(mission.dress, &"russia")
	assert_eq(mission.guards().size(), 8)
	var lights := 0
	for node in mission.find_children("*", "StaticBody3D", true, false):
		if node is Watchtower and (node as Watchtower).searchlight != null:
			lights += 1
	assert_eq(lights, 1)
	assert_eq(mission.title, "The guns")


func test_it_asks_for_three_lines_cut_and_the_store_destroyed() -> void:
	await _built()
	assert_eq(mission.objectives().size(), 2)
	var cut := mission.objectives()[0] as CutObjective
	assert_not_null(cut)
	assert_eq(cut.point_nodes().size(), 3)
	assert_eq(cut.current_hud_text(), "Cut the telephone lines: 3 left")
	var destroy := mission.objectives()[1] as DestroyObjective
	assert_not_null(destroy)
	assert_eq(destroy.hud_text, "Destroy the artillery store")


func test_the_cut_points_stand_apart_and_each_on_a_pole_of_the_line() -> void:
	await _built()
	var points := (mission.objectives()[0] as CutObjective).point_nodes()
	for i in points.size():
		var pole := mission.get_node(points[i].pole) as TelegraphPole
		assert_not_null(pole, String(points[i].name))
		assert_lt(BridgeBot.flat(pole.global_position, points[i].global_position), 0.1)
		assert_eq(pole.wires().size(), 2, "a pole with a line to cut")
		for j in range(i + 1, points.size()):
			assert_gt(BridgeBot.flat(points[i].global_position, points[j].global_position), 15.0)


func test_navmesh_is_well_inside_the_path_search_limit() -> void:
	await _built()
	var navmesh := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh
	assert_gt(navmesh.get_polygon_count(), 100)
	assert_lt(navmesh.get_polygon_count(), 2500)


func test_nobody_sees_the_start_in_the_first_twenty_seconds() -> void:
	await _built(true)
	var rules := _rules()
	_clock.engage()
	for i in 20 * 60:
		await get_tree().physics_frame
	for guard in mission.guards():
		assert_eq(guard.brain.state, GuardBrain.State.PATROL, String(guard.name))
	assert_eq(rules.alarm_level, 0)
	assert_eq(rules.result, MissionRules.Result.RUNNING)


func test_a_charge_in_the_yard_destroys_the_store_and_one_at_the_guns_does_not() -> void:
	await _built()
	var rules := _rules()
	var destroy := mission.objectives()[1] as DestroyObjective
	_blast(Vector3(12, 0, 0))
	assert_false(destroy.done, "the guns are not the store")
	_blast(Vector3(40.6, 0, 2))
	assert_true(destroy.done, "outside the east wall is near enough")
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_null(mission.get_node_or_null("Nav/TargetStack"), "the stack is gone")


func test_the_extraction_can_still_be_reached_once_the_store_is_gone() -> void:
	await _built()
	var rules := _rules()
	_blast(Vector3(40.6, 0, 2))
	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(3)
	assert_eq(rules.result, MissionRules.Result.RUNNING, "nobody is cut off")
	assert_true(_reaches(Vector3(47, 0, 13), mission.extraction().global_position))


func test_each_pole_and_the_store_can_be_got_to() -> void:
	await _built()
	var spawn := mission.specialist_spawns()[0].global_position
	for point in (mission.objectives()[0] as CutObjective).point_nodes():
		assert_true(_reaches(spawn, point.global_position + Vector3(0.6, 0, -1.2)), String(point.name))
	assert_true(_reaches(spawn, Vector3(40.6, 0, 2)))
	assert_true(_reaches(spawn, (mission.get_node("BridgeTarget") as Node3D).global_position), "and by the gate, into the yard")


func test_it_is_the_last_mission_and_winning_it_goes_back_to_the_list() -> void:
	assert_eq(Missions.id_at(Missions.LIST.size() - 1), "krasny_bor")
	Missions.choose(Missions.index_of("krasny_bor"))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	main.reload_action = func() -> void: pass
	main.rules.result = MissionRules.Result.WON
	main.rules.result_changed.emit(MissionRules.Result.WON)
	assert_eq(main.hud.end_screen.next_button.text, "Back to the missions")
	assert_true(main.hud.end_screen.note_label.visible)
	assert_string_contains(main.hud.end_screen.note_label.text, "3,645")
	main.hud.end_screen.next_button.pressed.emit()
	assert_eq(Missions.current, 0)
