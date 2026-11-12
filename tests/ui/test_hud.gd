extends GutTest

var mission: Mission
var rules: MissionRules
var specs: Array[Specialist]
var cam: IsoCamera
var input: PlayerInput
var overlay: VisionOverlay
var hud: Hud
var restarts := 0


func before_each() -> void:
	restarts = 0
	mission = load("res://tests/fixtures/flat_bridge.tscn").instantiate()
	# Live guards would shoot the specialists; these tests are about the display.
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	mission.build_nav()
	specs = mission.spawn_specialists()
	rules = MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specs)
	cam = IsoCamera.new()
	add_child_autofree(cam)
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, specs)
	overlay = VisionOverlay.new()
	add_child_autofree(overlay)
	hud = load("res://scenes/ui/hud.tscn").instantiate() as Hud
	add_child_autofree(hud)
	hud.setup(input, rules, specs, overlay)
	hud.restart_action = func() -> void: restarts += 1


func after_each() -> void:
	get_tree().paused = false
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = pos
	body.collision_layer = Perception.WORLD_MASK


func _lone_guard(pos: Vector3) -> Guard:
	var g := load("res://scenes/units/guard.tscn").instantiate() as Guard
	g.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(g)
	g.global_position = pos
	return g


func _plant(pos: Vector3, fuse: float) -> PlantedCharge:
	var charge := PlantedCharge.new()
	charge.fuse_left = fuse
	mission.add_child(charge)
	charge.global_position = pos
	return charge


func test_ammo_label_updates() -> void:
	input.select(specs[1])
	hud.refresh()
	var rifle: Button = hud.ability_buttons["rifle"]
	var before := rifle.text
	(specs[1].abilities["rifle"] as Ability).ammo = 2
	hud.refresh()
	assert_ne(rifle.text, before)
	assert_string_contains(rifle.text, "2")
	assert_false(hud.ability_buttons.has("charge"), "the bar shows the selected specialist's abilities")


func test_alarm_label_updates() -> void:
	hud.refresh()
	var calm := hud.alarm_label.text
	mission.guards()[0].brain.on_alarm(Vector3.ZERO)
	hud.refresh()
	assert_ne(hud.alarm_label.text, calm)
	assert_string_contains(hud.alarm_label.text, "1")


func test_portrait_health_updates() -> void:
	specs[0].take_damage(30)
	hud.refresh()
	assert_eq(hud.health_bars[0].value, 70.0)


func test_pause_indicator_and_restart_while_paused() -> void:
	assert_false(hud.pause_box.visible)
	input.set_paused(true)
	assert_true(hud.pause_box.visible)
	assert_eq(hud.pause_box.process_mode, Node.PROCESS_MODE_ALWAYS)
	hud.restart_button.pressed.emit()
	assert_eq(restarts, 1)
	assert_false(get_tree().paused, "restart clears the pause")


func test_end_screen_shows_on_result() -> void:
	assert_false(hud.end_screen.visible)
	specs[0].take_damage(1000)
	rules.evaluate()
	assert_true(hud.end_screen.visible)
	assert_eq(hud.end_screen.title_label.text, "Mission failed")


func test_end_screen_won_text() -> void:
	hud.end_screen.show_result(MissionRules.Result.WON)
	assert_eq(hud.end_screen.title_label.text, "Mission complete")


func test_restart_reloads_mission() -> void:
	hud.end_screen.show_result(MissionRules.Result.LOST)
	input.set_paused(true)
	hud.end_screen.restart_button.pressed.emit()
	assert_eq(restarts, 1)
	assert_false(get_tree().paused)


func test_show_message() -> void:
	hud.show_message("Out of ammo")
	assert_eq(hud.message_label.text, "Out of ammo")
	assert_true(hud.message_label.visible)


func test_refusal_becomes_message() -> void:
	input.order_refused.emit("out of ammo")
	assert_eq(hud.message_label.text, "out of ammo")


func test_crawling_label_follows_each_portraits_stance() -> void:
	hud.refresh()
	assert_eq(hud.stance_labels[0].text, "Crawling")
	assert_false(hud.stance_labels[0].visible)
	specs[1].set_stance(Unit.Stance.CRAWLING)
	hud.refresh()
	assert_false(hud.stance_labels[0].visible)
	assert_true(hud.stance_labels[1].visible)
	specs[1].set_stance(Unit.Stance.STANDING)
	hud.refresh()
	assert_false(hud.stance_labels[1].visible)


func test_fuse_label_counts_down_a_planted_charge() -> void:
	hud.refresh()
	assert_false(hud.fuse_label.visible, "no charge, no countdown")
	var charge := _plant(Vector3(-30, 0, 0), 7.5)
	hud.refresh()
	assert_true(hud.fuse_label.visible)
	assert_eq(hud.fuse_label.text, "Fuse: 8s")
	charge.advance(2.0)
	hud.refresh()
	assert_eq(hud.fuse_label.text, "Fuse: 6s")


func test_fuse_label_lists_two_charges_soonest_first() -> void:
	_plant(Vector3(-30, 0, 0), 9.0)
	_plant(Vector3(-30, 0, 4), 3.0)
	hud.refresh()
	assert_eq(hud.fuse_label.text, "Fuse: 3s, 9s")


func test_fuse_label_goes_when_the_charge_does() -> void:
	var charge := _plant(Vector3(-30, 0, 0), 1.0)
	hud.refresh()
	charge.advance(2.0)
	hud.refresh()
	assert_false(hud.fuse_label.visible, "a detonated charge is only waiting to be freed")


func test_blast_far_from_the_bridge_says_so() -> void:
	_plant(Vector3(-30, 0, 0), 1.0).advance(2.0)
	assert_eq(hud.message_label.text, "The charge was too far from the target")
	assert_true(hud.message_label.visible)


func test_blast_at_the_bridge_says_it_was_destroyed() -> void:
	_plant((mission.get_node("BridgeTarget") as Node3D).global_position, 1.0).advance(2.0)
	assert_eq(hud.message_label.text, "Bridge destroyed")


func test_widgets_let_mouse_through() -> void:
	for node in [hud.root, hud.top_bar, hud.bottom_bar, hud.alarm_label, hud.message_label,
			hud.fuse_label, hud.stance_labels[0]]:
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.name))


func test_ability_button_arms_through_input() -> void:
	input.select(specs[1])
	hud.refresh()
	(hud.ability_buttons["rifle"] as Button).pressed.emit()
	assert_eq(input.armed_ability, &"rifle")


func test_guard_click_shows_overlay_one_at_a_time() -> void:
	var a := _lone_guard(Vector3(0, 0, 0))
	var b := _lone_guard(Vector3(20, 0, 0))
	await wait_physics_frames(2)
	input.guard_clicked.emit(a)
	assert_true(overlay.visible)
	assert_eq(overlay.guard, a)
	input.guard_clicked.emit(b)
	assert_eq(overlay.guard, b)
	input.set_paused(false)
	overlay.hide_overlay()
	assert_false(overlay.visible)


## Behind a low wall a crawler is hidden but someone standing is still seen, at once inside the
## near range. The overlay must not leave that ground bare: it turns from red to yellow.
func test_overlay_turns_yellow_not_bare_behind_a_low_wall() -> void:
	var g := _lone_guard(Vector3.ZERO)
	await wait_physics_frames(2)
	overlay.show_for(g)
	var open_near := overlay.near_quads
	var open_far := overlay.far_quads
	assert_gt(open_near, 20)
	assert_gt(open_far, 20)
	_wall(Vector3(0, 0.5, -3), Vector3(30, 1, 0.5))
	await wait_physics_frames(2)
	overlay.rebuild()
	assert_lt(overlay.near_quads, open_near * 0.7, "a crawler is hidden behind it: less red")
	assert_gt(overlay.far_quads, open_far, "that ground is yellow now: a stander is seen there")
	assert_gt(overlay.near_quads + overlay.far_quads, (open_near + open_far) * 0.85,
			"almost none of the cone is left bare")
	overlay.hide_overlay()
	assert_eq(overlay.near_quads, 0)


func test_overlay_never_draws_red_and_yellow_on_the_same_ground() -> void:
	var g := _lone_guard(Vector3.ZERO)
	await wait_physics_frames(2)
	overlay.show_for(g)
	var rows := VisionOverlay.RAYS - 1
	var near_steps := int(g.vision.near_range / VisionOverlay.STEP)
	var far_steps := int(g.current_far_range() / VisionOverlay.STEP)
	assert_eq(overlay.near_quads, rows * near_steps, "open ground: red out to the near range")
	assert_eq(overlay.far_quads, rows * (far_steps - near_steps), "and yellow only beyond it")


func test_overlay_polygon_clipped_by_wall() -> void:
	var g := _lone_guard(Vector3.ZERO)
	_wall(Vector3(0, 1.5, -9), Vector3(30, 3, 0.5))
	await wait_physics_frames(2)
	overlay.show_for(g)
	assert_gt(overlay.far_polygon.size(), 2)
	for i in range(1, overlay.far_polygon.size()):
		var p := overlay.far_polygon[i]
		assert_lt(Vector2(p.x, p.z).length(), 12.0, "far zone (14 m open) stops at the wall 9 m away")
	for i in range(1, overlay.near_polygon.size()):
		assert_lte(Vector2(overlay.near_polygon[i].x, overlay.near_polygon[i].z).length(),
				g.vision.near_range + 0.01)


func test_overlay_far_range_grows_when_alerted() -> void:
	var g := _lone_guard(Vector3.ZERO)
	await wait_physics_frames(2)
	overlay.show_for(g)
	var calm := Vector2(overlay.far_polygon[1].x, overlay.far_polygon[1].z).length()
	g.brain.alerted = true
	overlay.rebuild()
	var alerted := Vector2(overlay.far_polygon[1].x, overlay.far_polygon[1].z).length()
	assert_gt(alerted, calm)


func test_overlay_hides_on_guard_death() -> void:
	var g := _lone_guard(Vector3.ZERO)
	await wait_physics_frames(2)
	overlay.show_for(g)
	assert_true(overlay.visible)
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.take_damage(1000)
	await wait_process_frames(2)
	assert_false(overlay.visible)
	assert_null(overlay.guard)


func test_overlay_hides_when_guard_freed() -> void:
	var g := _lone_guard(Vector3.ZERO)
	await wait_physics_frames(2)
	overlay.show_for(g)
	g.free()
	overlay._process(0.2)
	assert_false(overlay.visible)


# --- Objective line ---

func test_objective_line_follows_the_bridge() -> void:
	hud.refresh()
	assert_true(hud.objective_label.visible)
	assert_eq(hud.objective_label.text, "Objective: Destroy the bridge")
	rules.mission().objectives()[0].done = true
	hud.refresh()
	assert_eq(hud.objective_label.text, "Objective: Reach the extraction point")
	rules.mission().objectives()[0].done = false  # a load back to before the blast
	hud.refresh()
	assert_eq(hud.objective_label.text, "Objective: Destroy the bridge")


func test_objective_line_goes_when_the_mission_ends() -> void:
	rules.result = MissionRules.Result.WON
	hud.refresh()
	assert_false(hud.objective_label.visible)
	rules.result = MissionRules.Result.RUNNING
	hud.refresh()
	assert_true(hud.objective_label.visible)


# --- Pictures on the panels ---

func test_each_specialist_has_a_portrait_and_the_selected_one_a_bright_frame() -> void:
	hud.refresh()
	assert_eq(hud._portraits.size(), 2)
	var pictures := {}
	for panel in hud._portraits:
		var found := panel.find_children("*", "TextureRect", true, false)
		assert_eq(found.size(), 1)
		pictures[(found[0] as TextureRect).texture] = true
	assert_eq(pictures.size(), 2, "a different face for each")
	var frame := func(i: int) -> Color:
		return (hud._portraits[i].get_theme_stylebox("panel") as StyleBoxFlat).border_color
	assert_eq(frame.call(0), UiStyle.BRASS_BRIGHT, "the Dynamiter is selected")
	assert_eq(frame.call(1), UiStyle.BRASS)
	input.select(specs[1])
	hud.refresh()
	assert_eq(frame.call(1), UiStyle.BRASS_BRIGHT)
	assert_eq(frame.call(0), UiStyle.BRASS)


func test_ability_buttons_show_a_picture_the_key_and_what_is_left() -> void:
	hud.refresh()
	for id in ["knife", "charge", "pistol", "carry"]:
		var button := hud.ability_buttons[id] as Button
		assert_eq(button.icon, UiStyle.ICONS[StringName(id)], id)
		assert_eq(button.tooltip_text, Hud.LABELS[StringName(id)], "its name on hover")
	assert_eq((hud.ability_buttons["knife"] as Button).text, "Q", "the knife is not counted")
	assert_eq((hud.ability_buttons["charge"] as Button).text, "E  x2")
	input.select(specs[1])
	hud.refresh()
	assert_eq((hud.ability_buttons["rifle"] as Button).icon, UiStyle.ICONS[&"rifle"])


func test_an_armed_ability_has_a_bright_frame() -> void:
	hud.refresh()
	var knife := hud.ability_buttons["knife"] as Button
	assert_eq((knife.get_theme_stylebox("normal") as StyleBoxFlat).border_color, UiStyle.BRASS)
	input.arm_ability(&"knife")
	hud.refresh()
	assert_eq((knife.get_theme_stylebox("normal") as StyleBoxFlat).border_color, UiStyle.BRASS_BRIGHT)


# --- What really happened ---

func test_win_shows_what_really_happened() -> void:
	hud.end_screen.mission_id = "guadarrama"
	rules.result = MissionRules.Result.WON
	rules.result_changed.emit(MissionRules.Result.WON)
	assert_true(hud.end_screen.note_label.visible)
	assert_string_contains(hud.end_screen.note_label.text, "La Granja")


func test_loss_shows_no_note() -> void:
	hud.end_screen.mission_id = "guadarrama"
	rules.result = MissionRules.Result.LOST
	rules.result_changed.emit(MissionRules.Result.LOST)
	assert_false(hud.end_screen.note_label.visible)


func test_win_without_a_note_shows_none() -> void:
	hud.end_screen.mission_id = "powder_store"
	rules.result = MissionRules.Result.WON
	rules.result_changed.emit(MissionRules.Result.WON)
	assert_false(hud.end_screen.note_label.visible)
