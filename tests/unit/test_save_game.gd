extends GutTest
## Quick save and load against the real main scene, so the wiring under test is the wiring that ships.
## Guards are frozen (their holder is process-disabled) unless a test says otherwise; tests drive
## brains and fuses directly.

const TEST_PATH := "user://test_quicksave.json"
const BAD_SAVE := "This save can't be loaded. Restart the mission?"

var main: Node
var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var hud: Hud
var input: PlayerInput
var messages: Array[String] = []


func before_each() -> void:
	SaveGame.path = TEST_PATH
	_remove_save()
	messages.clear()
	SaveGame.message.connect(_on_message)
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	mission = main.mission
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	rules = main.rules
	specs = main.specialists
	hud = main.hud
	input = main.player_input


func after_each() -> void:
	SaveGame.message.disconnect(_on_message)
	SaveGame.path = SaveGame.SAVE_PATH
	get_tree().paused = false
	_remove_save()


func _on_message(text: String) -> void:
	messages.append(text)


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _write_save(text: String) -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().physics_frame


## The deferred rebake runs on an idle frame; several physics frames can pass before one does.
func _idle(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _save() -> void:
	assert_eq(SaveGame.quick_save(mission), OK, "saved")


func _load() -> void:
	assert_eq(SaveGame.quick_load(mission), OK, "loaded")


func _key(keycode: Key, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.pressed = true
	e.ctrl_pressed = ctrl
	input.handle_event(e)


func _guard(guard_name: String) -> Guard:
	return mission.get_node_or_null("Guards/" + guard_name) as Guard


func _kill(guard_name: String) -> Vector3:
	var g := _guard(guard_name)
	var at := g.global_position
	g.take_damage(1000)
	await get_tree().process_frame
	return at


func _bodies() -> Array[Node]:
	return get_tree().get_nodes_in_group(Body.GROUP)


func _charges() -> Array[Node]:
	return get_tree().get_nodes_in_group(PlantedCharge.GROUP)


func _plant(pos: Vector3, fuse := 10.0) -> PlantedCharge:
	var charge := PlantedCharge.new()
	charge.fuse_left = fuse
	mission.add_child(charge)
	charge.global_position = pos
	return charge


func _blow_bridge() -> void:
	_plant(mission.bridge_target().global_position, 0.0).advance(0.1)
	await _frames(1)


func _reaches(from: Vector3, to: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(mission.nav_map(), from, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) <= 1.0


func _crosses_gorge() -> bool:
	return _reaches(mission.specialist_spawns()[0].global_position, mission.extraction().global_position)


func _to_extraction(s: Specialist) -> void:
	s.global_position = mission.extraction().global_position + Vector3(0, -1.5, 0)


func _state_text() -> String:
	return JSON.stringify(mission.save_state(), "", true, true)


# --- The brief's roundtrips ---


func test_roundtrip_positions_hp_ammo() -> void:
	specs[0].global_position = Vector3(-20, 0.5, 4)
	specs[0].rotation.y = 0.75
	specs[0].take_damage(30)
	specs[0].set_stance(Unit.Stance.CRAWLING)
	specs[1].abilities["rifle"].ammo = 1
	_save()
	specs[0].global_position = Vector3(-25, 0.5, -3)
	specs[0].take_damage(20)
	specs[0].set_stance(Unit.Stance.STANDING)
	specs[1].abilities["rifle"].ammo = 0
	_load()
	assert_almost_eq(specs[0].global_position, Vector3(-20, 0.5, 4), Vector3.ONE * 0.001)
	assert_almost_eq(specs[0].rotation.y, 0.75, 0.001)
	assert_eq(specs[0].hp, specs[0].stats.max_hp - 30)
	assert_eq(specs[0].stance, Unit.Stance.CRAWLING)
	assert_eq(specs[1].abilities["rifle"].ammo, 1)
	assert_eq(messages[-1], "Game loaded")
	assert_eq(messages[-2], "Game saved")


func test_roundtrip_guard_state_and_alerted() -> void:
	var g := _guard("Guard1")
	g.brain.alerted = true
	g.brain.on_alarm(Vector3(1, 0, 2))
	g._waypoint = 1
	g._fire_timer = 0.7
	var vision_phase := g.vision_phase()
	var alarm_before := rules.alarm_level
	_save()
	g.brain.alerted = false
	g.brain.load_state({ "state": GuardBrain.State.PATROL, "alerted": false, "goal": [0, 0, 0],
			"far_total": 0.0, "no_sight": 0.0, "wait": 0.0, "arrived": false })
	g._waypoint = 0
	g._fire_timer = 0.0
	g.advance(0.03)
	_load()
	assert_eq(g.brain.state, GuardBrain.State.ALARM)
	assert_true(g.brain.alerted)
	assert_almost_eq(g.brain.goal_pos, Vector3(1, 0, 2), Vector3.ONE * 0.001)
	assert_eq(g.current_waypoint(), 1)
	assert_almost_eq(g._fire_timer, 0.7, 0.001)
	assert_almost_eq(g.vision_phase(), vision_phase, 0.001)
	assert_eq(rules.alarm_level, alarm_before)


func test_roundtrip_active_charge_fuse() -> void:
	var charge := _plant(Vector3(-20, 0.5, 4), 6.5)
	_save()
	charge.advance(2.0)
	_load()
	assert_eq(_charges().size(), 1)
	var loaded := _charges()[0] as PlantedCharge
	assert_almost_eq(loaded.fuse_left, 6.5, 0.001)
	assert_almost_eq(loaded.global_position, Vector3(-20, 0.5, 4), Vector3.ONE * 0.001)


func test_roundtrip_carried_body_keeps_carrier() -> void:
	await _kill("Guard1")
	var body := _bodies()[0] as Body
	body.found = true
	specs[0].pick_up(body)
	specs[0].global_position = Vector3(-20, 0.5, 4)
	_save()
	assert_eq(_read_save()["bodies"][0]["carrier"], String(specs[0].name), "a stable id, not a tree path")
	specs[0].drop_body()
	assert_true(specs[0].can_run)
	_load()
	assert_eq(_bodies().size(), 1)
	var loaded := _bodies()[0] as Body
	assert_eq(loaded.carried_by, specs[0])
	assert_eq(specs[0].carrying, loaded)
	assert_true(loaded.found)
	assert_false(specs[0].can_run, "a carrier only walks")
	specs[0].drop_body()
	assert_true(specs[0].can_run, "running comes back on drop")
	assert_null(loaded.carried_by)


func test_carried_body_keeps_following_after_load() -> void:
	await _kill("Guard1")
	specs[0].pick_up(_bodies()[0])
	_save()
	_load()
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_INHERIT
	specs[0].global_position += Vector3(2, 0, 0)
	await _frames(2)
	assert_almost_eq((_bodies()[0] as Body).global_position, specs[0].global_position, Vector3.ONE * 0.001)


func test_roundtrip_dead_guard_stays_body() -> void:
	var at := await _kill("Guard2")
	_save()
	_load()
	await _frames(1)
	assert_null(_guard("Guard2"), "the guard stays dead")
	assert_eq(_bodies().size(), 1)
	assert_almost_eq((_bodies()[0] as Node3D).global_position, at, Vector3.ONE * 0.001)
	assert_eq(mission.guards().size(), 2)


# --- Bad and missing saves ---


func test_load_without_save_shows_message() -> void:
	var before := _state_text()
	assert_eq(SaveGame.quick_load(mission), ERR_FILE_NOT_FOUND)
	assert_eq(messages, ["No save found"] as Array[String])
	assert_true(hud.message_label.visible)
	assert_eq(hud.message_label.text, "No save found")
	assert_false(hud.restart_offer.visible, "nothing is wrong with the mission")
	assert_eq(_state_text(), before)


func test_corrupt_json_offers_restart() -> void:
	specs[0].global_position = Vector3(-20, 0.5, 4)
	var before := _state_text()
	_write_save("{ this is not json")
	assert_ne(SaveGame.quick_load(mission), OK)
	assert_eq(messages, [BAD_SAVE] as Array[String])
	assert_eq(hud.message_label.text, BAD_SAVE)
	assert_true(hud.restart_offer.visible)
	assert_eq(_state_text(), before, "game state unchanged")


func test_old_version_offers_restart() -> void:
	_save()
	var d := _read_save()
	d["version"] = SaveGame.VERSION - 1
	_write_save(JSON.stringify(d))
	specs[0].global_position = Vector3(-20, 0.5, 4)
	var before := _state_text()
	messages.clear()
	assert_ne(SaveGame.quick_load(mission), OK)
	assert_eq(messages, [BAD_SAVE] as Array[String])
	assert_true(hud.restart_offer.visible)
	assert_eq(_state_text(), before, "game state unchanged")


## Each entry damages a good save somewhere deep; none may touch live state or raise an error.
func test_any_damaged_save_is_refused_whole() -> void:
	await _kill("Guard3")
	_plant(Vector3(-20, 0.5, 4))
	specs[0].pick_up(_bodies()[0])
	_save()
	var good := FileAccess.get_file_as_string(TEST_PATH)
	var damages := {
		"array root": func(_d: Dictionary) -> Variant: return [],
		"no version": func(d: Dictionary) -> Variant: d.erase("version"); return d,
		"text version": func(d: Dictionary) -> Variant: d["version"] = "1"; return d,
		"other mission": func(d: Dictionary) -> Variant: d["mission"] = "res://nope.tscn"; return d,
		"no specialists": func(d: Dictionary) -> Variant: d.erase("specialists"); return d,
		"one specialist": func(d: Dictionary) -> Variant: d["specialists"].pop_back(); return d,
		"twin specialists": func(d: Dictionary) -> Variant: d["specialists"][1]["id"] = d["specialists"][0]["id"]; return d,
		"short pos": func(d: Dictionary) -> Variant: d["specialists"][1]["pos"] = [1, 2]; return d,
		"text in pos": func(d: Dictionary) -> Variant: d["guards"][0]["pos"][0] = "x"; return d,
		"text hp": func(d: Dictionary) -> Variant: d["specialists"][0]["hp"] = "lots"; return d,
		"bad stance": func(d: Dictionary) -> Variant: d["specialists"][0]["stance"] = 9; return d,
		"alive at zero hp": func(d: Dictionary) -> Variant: d["specialists"][0]["hp"] = 0; return d,
		"missing ability": func(d: Dictionary) -> Variant: d["specialists"][0]["abilities"].erase("knife"); return d,
		"bad ammo": func(d: Dictionary) -> Variant: d["specialists"][0]["abilities"]["charge"]["ammo"] = -5; return d,
		"unknown guard": func(d: Dictionary) -> Variant: d["guards"][0]["id"] = "Guard99"; return d,
		"twin guards": func(d: Dictionary) -> Variant: d["guards"][1]["id"] = d["guards"][0]["id"]; return d,
		"waypoint off route": func(d: Dictionary) -> Variant: d["guards"][0]["waypoint"] = 999; return d,
		"bad brain state": func(d: Dictionary) -> Variant: d["guards"][1]["brain"]["state"] = 77; return d,
		"brain gone": func(d: Dictionary) -> Variant: d["guards"][1].erase("brain"); return d,
		"unknown carrier": func(d: Dictionary) -> Variant: d["bodies"][0]["carrier"] = "Nobody"; return d,
		"body not a dict": func(d: Dictionary) -> Variant: d["bodies"][0] = 3; return d,
		"negative fuse": func(d: Dictionary) -> Variant: d["charges"][0]["fuse_left"] = -1; return d,
		"bad result": func(d: Dictionary) -> Variant: d["rules"]["result"] = 7; return d,
		"unknown at extraction": func(d: Dictionary) -> Variant: d["rules"]["at_extraction"] = ["Nobody"]; return d,
		"no rules": func(d: Dictionary) -> Variant: d.erase("rules"); return d,
	}
	var before := _state_text()
	for damage_name in damages:
		var damaged: Variant = damages[damage_name].call(JSON.parse_string(good))
		_write_save(JSON.stringify(damaged))
		assert_ne(SaveGame.quick_load(mission), OK, damage_name)
		assert_eq(_state_text(), before, "unchanged after: " + damage_name)
	assert_eq(messages[-1], BAD_SAVE)


func test_restart_offer_uses_the_restart_path() -> void:
	var restarted := [0]
	hud.restart_action = func() -> void: restarted[0] += 1
	_write_save("nope")
	SaveGame.quick_load(mission)
	hud.restart_offer_button.pressed.emit()
	assert_eq(restarted[0], 1)
	assert_false(hud.restart_offer.visible)


func test_restart_offer_can_be_declined_and_a_good_load_clears_it() -> void:
	_write_save("nope")
	SaveGame.quick_load(mission)
	hud.keep_playing_button.pressed.emit()
	assert_false(hud.restart_offer.visible)
	assert_false(hud.message_label.visible)
	SaveGame.quick_load(mission)
	assert_true(hud.restart_offer.visible)
	_save()
	assert_false(hud.restart_offer.visible, "a later message clears the offer")


func test_restart_offer_outlives_the_message_time() -> void:
	_write_save("nope")
	SaveGame.quick_load(mission)
	hud._process(Hud.MESSAGE_SECONDS + 1.0)
	assert_true(hud.message_label.visible, "the question stays up until it is answered")
	assert_true(hud.restart_offer.visible)


# --- After a result ---


func test_load_after_result_clears_end_screen() -> void:
	_save()
	specs[0].take_damage(1000)
	await _frames()
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_true(hud.end_screen.visible)
	assert_false(input.orders_enabled)
	_key(KEY_L)
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_false(hud.end_screen.visible)
	assert_true(input.orders_enabled)
	assert_true(specs[0].alive)
	assert_eq(specs[0].hp, specs[0].stats.max_hp)
	await _frames()
	assert_eq(rules.result, MissionRules.Result.RUNNING, "stays running")
	assert_false(get_tree().paused)


func test_load_after_win_clears_end_screen() -> void:
	_save()
	await _blow_bridge()
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames(4)
	assert_eq(rules.result, MissionRules.Result.WON)
	_load()
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_false(hud.end_screen.visible)
	assert_false(rules.bridge_destroyed)


func test_load_keeps_the_players_pause_and_hud_agrees() -> void:
	_save()
	input.set_paused(true)
	_key(KEY_L)
	assert_true(input.is_paused(), "load does not unpause behind the player's back")
	assert_eq(messages[-1], "Game loaded")
	hud.refresh()
	assert_true(hud.pause_box.visible)
	input.set_paused(false)
	hud.refresh()
	assert_false(hud.pause_box.visible)


func test_load_reselects_a_living_specialist() -> void:
	input.select(specs[1])
	_save()
	specs[1].take_damage(1000)
	specs[0].take_damage(1000)
	await _frames()
	assert_null(input.selected)
	_load()
	assert_not_null(input.selected)
	assert_true(input.selected.alive)
	await _frames()
	assert_true(input._can_order(), "orders flow again")


func test_load_disarms_the_armed_ability() -> void:
	_save()
	_key(KEY_Q)
	assert_eq(input.armed_ability, &"knife")
	_load()
	assert_eq(input.armed_ability, &"")


# --- Keys ---


func test_o_and_l_keys_save_and_load_while_paused() -> void:
	input.set_paused(true)
	specs[0].global_position = Vector3(-20, 0.5, 4)
	_key(KEY_O)
	assert_eq(messages[-1], "Game saved")
	assert_true(FileAccess.file_exists(TEST_PATH))
	specs[0].global_position = Vector3(-25, 0.5, -3)
	_key(KEY_L)
	assert_eq(messages[-1], "Game loaded")
	assert_almost_eq(specs[0].global_position, Vector3(-20, 0.5, 4), Vector3.ONE * 0.001)


func test_o_key_saves_after_a_result() -> void:
	specs[0].take_damage(1000)
	await _frames()
	_key(KEY_O)
	assert_eq(messages[-1], "Game saved")
	_key(KEY_L)
	assert_eq(messages[-1], "Game loaded")
	assert_eq(rules.result, MissionRules.Result.LOST, "a save made after the loss is that loss")
	assert_false(input.orders_enabled)
	assert_true(hud.end_screen.visible)


func test_browser_shortcuts_are_left_alone() -> void:
	_key(KEY_L, true)
	_key(KEY_O, true)
	_key(KEY_F5)
	assert_eq(messages.size(), 0)


func test_save_is_json_at_the_set_path_with_version() -> void:
	_save()
	assert_eq(SaveGame.SAVE_PATH, "user://quicksave.json")
	assert_eq(int(_read_save()["version"]), 1)


# --- Guards come and go ---


func test_guard_killed_since_save_comes_back_on_its_route() -> void:
	var g := _guard("Guard2")
	var route_size := g.route_size()
	g._waypoint = 1
	var pos := g.global_position
	_save()
	await _kill("Guard2")
	_load()
	var back := _guard("Guard2")
	assert_not_null(back, "same id, same name")
	assert_true(back.alive)
	assert_eq(back.hp, back.stats.max_hp)
	assert_almost_eq(back.global_position, pos, Vector3.ONE * 0.001)
	assert_eq(back.route_size(), route_size)
	assert_eq(back.current_waypoint(), 1)
	assert_eq(_bodies().size(), 0, "its body from after the save is gone")
	assert_eq(mission.guards().size(), 3)
	assert_eq(get_tree().get_nodes_in_group(Guard.GROUP).size(), 3)


func test_guard_killed_in_the_same_frame_as_the_load_comes_back_cleanly() -> void:
	_save()
	_guard("Guard2").take_damage(1000)
	_load()
	assert_not_null(_guard("Guard2"), "the dying node must not take the name")
	assert_eq(mission.guards().size(), 3)
	assert_eq(_bodies().size(), 0)
	await _frames()
	assert_eq(mission.guards().size(), 3)
	assert_true(_guard("Guard2").alive)


func test_restored_guard_walks_again() -> void:
	_save()
	await _kill("Guard1")
	_load()
	var back := _guard("Guard1")
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_INHERIT
	var from := back.global_position
	await _frames(20)
	assert_gt(back.global_position.distance_to(from), 0.1, "still has its nav map and its order")


func test_guard_alive_now_but_dead_in_save_goes() -> void:
	await _kill("Guard3")
	_save()
	# Nothing can resurrect a guard in play, so stand in for "alive now" with a guard from an earlier load.
	var earlier := _read_save()
	await _kill("Guard1")
	_save()
	var dead_in_save := _read_save()
	_write_save(JSON.stringify(earlier))
	_load()
	assert_not_null(_guard("Guard1"))
	_write_save(JSON.stringify(dead_in_save))
	_load()
	assert_null(_guard("Guard1"), "alive now, dead in the save")
	assert_null(_guard("Guard3"))
	assert_eq(get_tree().get_nodes_in_group(Guard.GROUP).size(), 1)
	assert_eq(_bodies().size(), 2)


func test_loaded_guards_still_share_alarms() -> void:
	_save()
	await _kill("Guard1")
	_load()
	var back := _guard("Guard1")
	var other := _guard("Guard2")
	back.brain.tick(0.1, Vision.Zone.NEAR, Vector3(1, 0, 1), false)
	assert_eq(other.brain.state, GuardBrain.State.ALARM, "restored guard alarms a survivor")
	assert_eq(_guard("Guard3").brain.state, GuardBrain.State.ALARM)
	_save()
	await _kill("Guard3")
	_load()
	# Now everyone is in ALARM from the save; stand one down and raise from a survivor.
	back = _guard("Guard1")
	back.brain.load_state({ "state": GuardBrain.State.PATROL, "alerted": false, "goal": [0, 0, 0],
			"far_total": 0.0, "no_sight": 0.0, "wait": 0.0, "arrived": false })
	var third := _guard("Guard3")
	third.brain.load_state({ "state": GuardBrain.State.PATROL, "alerted": false, "goal": [0, 0, 0],
			"far_total": 0.0, "no_sight": 0.0, "wait": 0.0, "arrived": false })
	_guard("Guard2").brain.load_state({ "state": GuardBrain.State.PATROL, "alerted": false, "goal": [0, 0, 0],
			"far_total": 0.0, "no_sight": 0.0, "wait": 0.0, "arrived": false })
	_guard("Guard2").brain.tick(0.1, Vision.Zone.NEAR, Vector3(2, 0, 2), false)
	assert_eq(back.brain.state, GuardBrain.State.ALARM, "survivor alarms a restored guard")
	assert_eq(third.brain.state, GuardBrain.State.ALARM)


func test_restored_guard_still_hears_and_dies_into_a_body() -> void:
	_save()
	await _kill("Guard1")
	_load()
	var back := _guard("Guard1")
	NoiseBus.emit_noise(back.global_position, 5.0)
	assert_eq(back.brain.state, GuardBrain.State.INVESTIGATE)
	back.take_damage(1000)
	await get_tree().process_frame
	assert_eq(_bodies().size(), 1)


func test_guard_keeps_its_stopped_alarm_stance() -> void:
	var g := _guard("Guard1")
	g.brain.on_alarm(g.global_position + Vector3(1, 0, 0))
	g.stop()
	_save()
	_load()
	assert_false(g._moving, "a guard stopped to shoot does not start walking on load")


# --- Bodies and charges come and go ---


func test_body_since_save_disappears() -> void:
	_save()
	await _kill("Guard1")
	await _kill("Guard2")
	assert_eq(_bodies().size(), 2)
	_load()
	assert_eq(_bodies().size(), 0)


func test_charge_since_save_disappears_and_cannot_fire() -> void:
	_save()
	var stale := _plant(mission.bridge_target().global_position, 0.05)
	_load()
	assert_false(is_instance_valid(stale), "gone at once, not at the end of the frame")
	assert_eq(_charges().size(), 0)
	await _frames(8)
	assert_false(rules.bridge_destroyed)
	assert_not_null(mission.get_node_or_null("Nav/BridgeDeck"))


func test_loaded_charge_blows_the_bridge_and_counts_for_the_win() -> void:
	_plant(mission.bridge_target().global_position, 6.0)
	_save()
	for c in _charges():
		c.free()
	_load()
	var loaded := _charges()[0] as PlantedCharge
	var blown := [0]
	rules.bridge_blown.connect(func() -> void: blown[0] += 1)
	loaded.advance(7.0)
	assert_eq(blown[0], 1, "rules hooked the restored charge")
	assert_true(rules.bridge_destroyed)
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames(4)
	assert_eq(rules.result, MissionRules.Result.WON)


func test_spent_ability_charge_restored_with_the_count() -> void:
	specs[0].global_position = Vector3(-20, 0.5, 4)
	var ability: Ability = specs[0].abilities["charge"]
	ability.use(specs[0], null)
	var left: int = ability.ammo
	_save()
	ability.use(specs[0], null)
	assert_eq(_charges().size(), 2)
	_load()
	assert_eq(ability.ammo, left)
	assert_eq(_charges().size(), 1)


# --- Specialists after a load ---


func test_loaded_specialist_death_still_loses() -> void:
	_save()
	specs[1].take_damage(1000)
	await _frames()
	_load()
	await _frames()
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	specs[1].take_damage(1000)
	await _frames()
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_true(hud.end_screen.visible)


func test_specialist_in_transit_keeps_walking() -> void:
	specs[0].move_to(specs[0].global_position + Vector3(6, 0, 0), true)
	await _frames(2)
	_save()
	specs[0].stop()
	_load()
	assert_true(specs[0]._moving)
	var from := specs[0].global_position
	await _frames(10)
	assert_gt(specs[0].global_position.distance_to(from), 0.2)


# --- The bridge ---


func test_load_restores_a_destroyed_bridge() -> void:
	await _blow_bridge()
	await _idle()
	_save()
	await get_tree().process_frame
	# A fresh look at the same save: live state already broken, still broken after.
	_load()
	await _idle()
	assert_true(rules.bridge_destroyed)
	assert_null(mission.get_node_or_null("Nav/BridgeDeck"))
	assert_not_null(mission.get_node_or_null("Nav/BridgeBroken"))
	assert_false(_crosses_gorge())


func test_load_breaks_an_intact_live_bridge_when_the_save_says_broken() -> void:
	# Written by hand from a live save: the mission itself never un-breaks.
	await _blow_bridge()
	await _idle()
	_save()
	var broken := _read_save()
	broken["rules"]["bridge_destroyed"] = false
	_write_save(JSON.stringify(broken))
	_load()
	await _idle()
	broken["rules"]["bridge_destroyed"] = true
	_write_save(JSON.stringify(broken))
	assert_not_null(mission.get_node_or_null("Nav/BridgeDeck"), "precondition: intact")
	_load()
	await _idle()
	assert_null(mission.get_node_or_null("Nav/BridgeDeck"))
	assert_true(rules.bridge_destroyed)
	assert_false(_crosses_gorge())


func test_intact_bridge_in_save_rebuilds_a_broken_live_bridge() -> void:
	assert_true(_crosses_gorge(), "precondition")
	_save()
	await _blow_bridge()
	await _idle()
	assert_false(_crosses_gorge(), "precondition: broken")
	_load()
	assert_false(rules.bridge_destroyed)
	await _idle()
	assert_not_null(mission.get_node_or_null("Nav/BridgeDeck"), "deck is back")
	assert_null(mission.get_node_or_null("Nav/BridgeBroken"), "stubs are gone")
	assert_true(_crosses_gorge(), "the navmesh crosses again")
	var deck := mission.get_node("Nav/BridgeDeck") as CSGBox3D
	assert_true(deck.use_collision, "and it can be walked on")


func test_bridge_can_blow_again_after_being_rebuilt() -> void:
	_save()
	await _blow_bridge()
	await _idle()
	_load()
	await _idle()
	var blown := [0]
	rules.bridge_blown.connect(func() -> void: blown[0] += 1)
	await _blow_bridge()
	await _idle()
	assert_eq(blown[0], 1)
	assert_true(rules.bridge_destroyed)
	assert_false(_crosses_gorge())


func test_specialist_walks_across_the_rebuilt_bridge() -> void:
	var deck_pos := (mission.get_node("Nav/BridgeDeck") as Node3D).global_position
	specs[0].global_position = deck_pos + Vector3(-12, 0, 0)
	_save()
	await _blow_bridge()
	await _idle()
	_load()
	await _idle()
	specs[0].move_to(deck_pos + Vector3(12, 0, 0), true)
	await _frames(150)
	assert_gt(specs[0].global_position.x, deck_pos.x + 1.0, "reached the far side")
	assert_gt(specs[0].global_position.y, deck_pos.y - 2.0, "did not fall in")


func test_specialist_in_transit_crosses_the_rebuilt_bridge() -> void:
	var deck_pos := (mission.get_node("Nav/BridgeDeck") as Node3D).global_position
	specs[0].global_position = deck_pos + Vector3(-12, 0, 0)
	specs[0].move_to(deck_pos + Vector3(12, 0, 0), true)
	await _frames(1)
	_save()
	await _blow_bridge()
	await _idle()
	_load()
	await _frames(150)
	assert_gt(specs[0].global_position.x, deck_pos.x + 1.0, "its order survives the navmesh changing under it")


func test_stale_rebake_does_not_fire_across_a_load() -> void:
	_save()
	# The bridge breaks and is restored before the deferred rebake has had its frame.
	_plant(mission.bridge_target().global_position, 0.0).advance(0.1)
	assert_true(rules.bridge_destroyed)
	var bakes := mission.nav_bakes
	_load()
	await _idle(4)
	assert_eq(mission.nav_bakes, bakes + 1, "only the rebake for the restored bridge runs")
	assert_true(_crosses_gorge())
	assert_not_null(mission.get_node_or_null("Nav/BridgeDeck"))


func test_load_while_a_break_is_pending_keeps_its_rebake() -> void:
	_plant(mission.bridge_target().global_position, 0.0).advance(0.1)
	_save()
	var bakes := mission.nav_bakes
	_load()
	await _idle(3)
	assert_eq(mission.nav_bakes, bakes + 1, "the break's own rebake still has to run")
	assert_false(_crosses_gorge())


func test_load_with_the_bridge_already_broken_does_not_rebake() -> void:
	await _blow_bridge()
	await _idle()
	_save()
	var bakes := mission.nav_bakes
	_load()
	await _idle(3)
	assert_eq(mission.nav_bakes, bakes)
	assert_false(_crosses_gorge())


func test_a_load_with_no_bridge_change_does_not_rebake() -> void:
	_save()
	var bakes := mission.nav_bakes
	_load()
	await _idle(3)
	assert_eq(mission.nav_bakes, bakes)


# --- Extraction tracking ---


func test_no_false_win_from_stale_extraction_tracking() -> void:
	# In the save: bridge down, nobody at extraction. Live: bridge up, both at extraction.
	await _blow_bridge()
	await _idle()
	_save()
	var broken := _read_save()
	broken["rules"]["bridge_destroyed"] = false
	_write_save(JSON.stringify(broken))
	_load()
	await _idle()
	_to_extraction(specs[0])
	_to_extraction(specs[1])
	await _frames(4)
	assert_true(rules.at_extraction(specs[0]), "precondition: live tracking says inside")
	broken["rules"]["bridge_destroyed"] = true
	_write_save(JSON.stringify(broken))
	_load()
	rules.evaluate()
	assert_eq(rules.result, MissionRules.Result.RUNNING, "the save has them outside")
	await _frames(4)
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_false(rules.at_extraction(specs[0]))


func test_extraction_presence_survives_a_load() -> void:
	_to_extraction(specs[0])
	await _frames(4)
	assert_true(rules.at_extraction(specs[0]), "precondition")
	_save()
	specs[0].global_position = mission.specialist_spawns()[0].global_position
	await _frames(4)
	assert_false(rules.at_extraction(specs[0]), "precondition: walked out")
	_load()
	assert_true(rules.at_extraction(specs[0]))
	await _frames(4)
	assert_true(rules.at_extraction(specs[0]))
