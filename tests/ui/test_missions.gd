extends GutTest
## More than one mission: the list, choosing one, and going on to the next.


func before_each() -> void:
	Campaign.reset()


func after_each() -> void:
	Campaign.reset()
	Missions.current = 0
	Briefing.seen = false
	get_tree().paused = false


func _game() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	return main


func test_the_list_names_missions_that_exist() -> void:
	assert_eq(Missions.LIST.size(), 5)
	assert_eq(Missions.LIST.map(func(e: Dictionary) -> String: return e["id"]), ["guadarrama", "teruel", "carchuna", "ebro", "volkhov"],
			"in the order of their dates")
	var ids := {}
	for entry: Dictionary in Missions.LIST:
		assert_true(ResourceLoader.exists(entry["path"]), entry["path"])
		assert_ne(entry["name"], "")
		ids[entry["id"]] = true
	assert_eq(ids.size(), Missions.LIST.size(), "each with its own id")
	assert_eq(Missions.path(), Missions.LIST[0]["path"], "the first is where a new player starts")


func test_choosing_moves_through_the_list_and_stops_at_its_ends() -> void:
	assert_true(Missions.has_next())
	Missions.choose(1)
	assert_eq(Missions.path(), Missions.LIST[1]["path"])
	Missions.choose(99)
	assert_eq(Missions.current, Missions.LIST.size() - 1)
	assert_false(Missions.has_next())
	Missions.choose(-3)
	assert_eq(Missions.current, 0)
	assert_eq(Missions.index_of("powder_store"), 1)
	assert_eq(Missions.index_of("no such mission"), -1)


func test_the_game_loads_the_chosen_mission_with_its_own_words() -> void:
	Missions.choose(1)
	var main := await _game()
	assert_eq(main.mission.title, "The depot outside Teruel")
	assert_eq(MissionValidator.validate(main.mission), PackedStringArray())
	main.hud.refresh()
	assert_eq(main.hud.objective_label.text, "Objective: Destroy the depot")
	var b: Briefing = main.open_briefing()
	var text := ""
	for label in b.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	assert_string_contains(text, "The depot outside Teruel")
	assert_string_contains(text, "stores stacked in the farm's yard")
	assert_false(text.contains("railway bridge"), "not the first mission's briefing")


func test_the_briefing_offers_the_other_missions() -> void:
	Campaign.mark_won(Missions.id_at(0))
	var main := await _game()
	var b: Briefing = main.open_briefing()
	assert_eq(b.mission_buttons.size(), Missions.LIST.size())
	assert_true(b.mission_buttons[0].disabled, "the one being played is marked, not offered")
	assert_false(b.mission_buttons[1].disabled)
	var reloads := [0]
	main.reload_action = func() -> void: reloads[0] += 1
	Briefing.seen = true
	b.mission_buttons[1].pressed.emit()
	assert_eq(Missions.current, 1)
	assert_eq(reloads[0], 1, "the game starts again on the chosen mission")
	assert_false(Briefing.seen, "and briefs the player on it")


func test_winning_offers_the_next_mission_until_there_is_none() -> void:
	var main := await _game()
	var reloads := [0]
	main.reload_action = func() -> void: reloads[0] += 1
	assert_false(main.hud.end_screen.next_button.visible)
	main.rules.result = MissionRules.Result.WON
	main.rules.result_changed.emit(MissionRules.Result.WON)
	assert_true(main.hud.end_screen.next_button.visible)
	main.hud.end_screen.next_button.pressed.emit()
	assert_eq(Missions.current, 1)
	assert_eq(reloads[0], 1)


func test_after_the_last_mission_the_way_on_is_back_to_the_list() -> void:
	Missions.choose(Missions.LIST.size() - 1)
	var main := await _game()
	var reloads := [0]
	main.reload_action = func() -> void: reloads[0] += 1
	main.rules.result = MissionRules.Result.WON
	main.rules.result_changed.emit(MissionRules.Result.WON)
	assert_true(main.hud.end_screen.next_button.visible)
	assert_eq(main.hud.end_screen.next_button.text, "Back to the missions")
	main.hud.end_screen.next_button.pressed.emit()
	assert_eq(Missions.current, 0)
	assert_eq(reloads[0], 1)


func test_no_way_on_after_a_loss() -> void:
	var first := await _game()
	first.rules.result = MissionRules.Result.LOST
	first.rules.result_changed.emit(MissionRules.Result.LOST)
	assert_false(first.hud.end_screen.next_button.visible, "a lost mission is retried, not skipped")


func test_winning_is_remembered_and_opens_the_next() -> void:
	var main := await _game()
	assert_false(Campaign.is_open(1))
	main.rules.result = MissionRules.Result.WON
	main.rules.result_changed.emit(MissionRules.Result.WON)
	assert_true(Campaign.is_won(Missions.id_at(0)))
	assert_true(Campaign.is_open(1))
	assert_string_contains(main.hud.end_screen.note_label.text, "La Granja")


func test_losing_is_not_remembered_as_a_win() -> void:
	var main := await _game()
	main.rules.result = MissionRules.Result.LOST
	main.rules.result_changed.emit(MissionRules.Result.LOST)
	assert_false(Campaign.is_won(Missions.id_at(0)))


func test_old_ids_open_the_reframed_missions() -> void:
	assert_eq(Missions.index_of("guadarrama"), 0)
	assert_eq(Missions.index_of("bridge"), Missions.index_of("guadarrama"))
	assert_eq(Missions.index_of("bridge_night"), Missions.index_of("guadarrama"))
	assert_eq(Missions.index_of("powder_store_night"), Missions.index_of("teruel"))
	assert_eq(Missions.index_of("nowhere"), -1)
	assert_eq(Missions.id_at(0), "guadarrama")
	for entry: Dictionary in Missions.LIST:
		assert_false(String(entry["id"]).ends_with("_night"), "night is not a mission of its own")


func test_each_mission_says_where_and_when_or_neither() -> void:
	for entry: Dictionary in Missions.LIST:
		assert_eq(entry["place"] == "", entry["date"] == "", entry["id"])


func test_the_powder_store_is_teruel_now() -> void:
	assert_eq(Missions.id_at(1), "teruel")
	assert_eq(Missions.index_of("powder_store"), 1)
	assert_eq(Missions.index_of("powder_store_night"), 1)
	assert_eq(Missions.LIST[1]["place"], "Teruel")
	assert_eq(Missions.LIST[1]["date"], "December 1937")
