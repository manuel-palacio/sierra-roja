extends GutTest
## The opening screen, alone and wired into the game.

var starts := 0


func before_each() -> void:
	starts = 0
	Briefing.seen = false


func after_each() -> void:
	get_tree().paused = false


func _briefing() -> Briefing:
	var b := Briefing.new()
	add_child_autofree(b)
	b.started.connect(func() -> void: starts += 1)
	return b


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _all_text(node: Node) -> String:
	var out := ""
	for label in node.find_children("*", "Label", true, false):
		out += (label as Label).text + "\n"
	return out


func test_it_says_what_to_do_and_how() -> void:
	var b := _briefing()
	var text := _all_text(b)
	assert_eq(b.title_label.text, "Sierra Roja")
	assert_string_contains(text, "The bridge at night")
	assert_string_contains(text, "Destroy the railway bridge")
	assert_string_contains(text, "Get both of them to the extraction point")
	for needle in ["Left click", "Double-click", "Crawl", "Knife", "Charge", "Rifle", "Pistol", "Carry",
			"Pause", "Quick save", "Z / X", "Mouse wheel"]:
		assert_string_contains(text, needle)
	assert_eq(b.start_button.text, "Start")


func test_the_button_starts_once_and_the_screen_goes() -> void:
	var b := _briefing()
	assert_true(b.visible)
	b.start_button.pressed.emit()
	assert_eq(starts, 1)
	assert_false(b.visible)
	b.start_button.pressed.emit()
	b._input(_key(KEY_ENTER))
	assert_eq(starts, 1, "only once")


func test_enter_and_space_start_and_other_keys_do_not() -> void:
	for code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		starts = 0
		var b := _briefing()
		b._input(_key(KEY_C))
		b._input(_key(KEY_O))
		assert_eq(starts, 0)
		b._input(_key(code))
		assert_eq(starts, 1, "key %d starts" % code)


func test_it_is_not_wanted_in_a_headless_run() -> void:
	assert_false(Briefing.wanted(), "tests and probes go straight to the game")


# --- In the game ---

func _game() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	return main


func test_no_orders_until_the_start() -> void:
	var main := await _game()
	assert_null(main.briefing, "none in a headless run")
	assert_true(main.player_input.orders_enabled)
	var b: Briefing = main.open_briefing()
	assert_eq(main.briefing, b)
	assert_false(main.player_input.orders_enabled)
	assert_false(main.camera.edge_scroll_enabled, "the view stays on the squad")
	assert_false(get_tree().paused, "the night goes on behind the briefing")
	b.start_button.pressed.emit()
	assert_true(main.player_input.orders_enabled)
	assert_true(main.camera.edge_scroll_enabled)
	assert_null(main.briefing)


func test_space_on_the_briefing_starts_the_game_without_pausing_it() -> void:
	var main := await _game()
	main.open_briefing()
	get_viewport().push_input(_key(KEY_SPACE))
	assert_true(main.player_input.orders_enabled, "started")
	assert_false(get_tree().paused, "and the same key press did not pause the game")
	get_viewport().push_input(_key(KEY_SPACE))
	assert_true(get_tree().paused, "after that, Space pauses as usual")


func test_keys_on_the_briefing_do_not_reach_the_game() -> void:
	var main := await _game()
	main.open_briefing()
	var seen: Array = []
	SaveGame.message.connect(func(text: String) -> void: seen.append(text))
	main.player_input.order_refused.connect(func(text: String) -> void: seen.append(text))
	for code in [KEY_O, KEY_L, KEY_Q, KEY_C, KEY_2]:
		get_viewport().push_input(_key(code))
	assert_eq(seen, [], "no save, load or refusal messages")
	assert_eq(main.player_input.selected, main.specialists[0])


func test_a_mission_already_over_stays_closed_to_orders_after_the_start() -> void:
	var main := await _game()
	var b: Briefing = main.open_briefing()
	main.specialists[1].take_damage(1000)
	await get_tree().process_frame
	assert_eq(main.rules.result, MissionRules.Result.LOST)
	b.start_button.pressed.emit()
	assert_false(main.player_input.orders_enabled)


func test_once_started_it_is_not_put_up_again_on_a_restart() -> void:
	assert_false(Briefing.seen)
	var b := _briefing()
	b.begin()
	assert_true(Briefing.seen, "remembered for the rest of the session, across mission restarts")
	assert_false(Briefing.wanted())
