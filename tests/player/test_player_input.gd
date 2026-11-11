extends GutTest

var cam: IsoCamera
var input: PlayerInput
var dyn: Specialist
var mark: Specialist
var now := 0.0
var picked := {}
var guards_clicked: Array = []
var refusals: Array = []


func before_each() -> void:
	cam = IsoCamera.new()
	add_child_autofree(cam)
	dyn = _specialist(PackedStringArray(["knife", "charge", "pistol", "carry"]), Vector3(0, 0, 0))
	mark = _specialist(PackedStringArray(["rifle", "pistol"]), Vector3(5, 0, 0))
	input = PlayerInput.new()
	add_child_autofree(input)
	input.setup(cam, [dyn, mark])
	input.picker = func(_pos: Vector2) -> Dictionary: return picked
	input.clock = func() -> float: return now
	picked = {}
	now = 10.0
	guards_clicked.clear()
	refusals.clear()
	input.guard_clicked.connect(func(g: Guard) -> void: guards_clicked.append(g))
	input.order_refused.connect(func(r: String) -> void: refusals.append(r))


func after_each() -> void:
	get_tree().paused = false
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func _specialist(ids: PackedStringArray, pos: Vector3) -> Specialist:
	var s := load("res://scenes/units/specialist.tscn").instantiate() as Specialist
	s.ability_ids = ids
	add_child_autofree(s)
	s.global_position = pos
	return s


func _guard(pos: Vector3) -> Guard:
	var g := load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(g)
	g.global_position = pos
	return g


func _key(code: Key, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	return e


func _click(button := MOUSE_BUTTON_LEFT, pos := Vector2(100, 100)) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = pos
	return e


func _target(s: Specialist) -> Vector3:
	return (s.get_node("NavigationAgent3D") as NavigationAgent3D).target_position


func _ground(pos: Vector3) -> Dictionary:
	return { "collider": null, "position": pos }


func test_dynamiter_selected_by_default() -> void:
	assert_eq(input.selected, dyn)


func test_keys_select_1_2() -> void:
	input.handle_event(_key(KEY_2))
	assert_eq(input.selected, mark)
	input.handle_event(_key(KEY_1))
	assert_eq(input.selected, dyn)


func test_selection_changed_emitted() -> void:
	watch_signals(input)
	input.handle_event(_key(KEY_2))
	assert_signal_emitted_with_parameters(input, "selection_changed", [mark])


func test_click_moves_selected() -> void:
	picked = _ground(Vector3(8, 0, 3))
	input.handle_event(_click())
	assert_eq(_target(dyn), Vector3(8, 0, 3))
	assert_ne(dyn.current_speed(), dyn.stats.run_speed)


func test_double_click_runs() -> void:
	picked = _ground(Vector3(8, 0, 3))
	input.handle_event(_click())
	now += 0.2
	input.handle_event(_click())
	assert_eq(dyn.current_speed(), dyn.stats.run_speed)


func test_slow_second_click_walks() -> void:
	picked = _ground(Vector3(8, 0, 3))
	input.handle_event(_click())
	now += 0.4
	input.handle_event(_click())
	assert_ne(dyn.current_speed(), dyn.stats.run_speed)


func test_click_on_specialist_selects() -> void:
	picked = { "collider": mark, "position": mark.global_position }
	input.handle_event(_click())
	assert_eq(input.selected, mark)
	assert_eq(_target(dyn), Vector3.ZERO)


func test_guard_click_orders_nothing_and_signals() -> void:
	var g := _guard(Vector3(9, 0, 9))
	picked = { "collider": g, "position": g.global_position }
	input.handle_event(_click())
	assert_eq(guards_clicked, [g])
	assert_eq(_target(dyn), Vector3.ZERO)


func test_c_toggles_stance() -> void:
	input.handle_event(_key(KEY_C))
	assert_eq(dyn.stance, Unit.Stance.CRAWLING)
	input.handle_event(_key(KEY_C))
	assert_eq(dyn.stance, Unit.Stance.STANDING)


func test_armed_ability_targets_next_click() -> void:
	var g := _guard(Vector3(1, 0, 0))
	input.handle_event(_key(KEY_Q))
	assert_eq(input.armed_ability, &"knife")
	picked = { "collider": g, "position": g.global_position }
	input.handle_event(_click())
	assert_false(g.alive)
	assert_eq(input.armed_ability, &"")
	assert_eq(_target(dyn), Vector3.ZERO, "targeting must not also move")


func test_ability_on_invalid_target_refused() -> void:
	var g := _guard(Vector3(10, 0, 0))
	input.handle_event(_key(KEY_Q))
	picked = { "collider": g, "position": g.global_position }
	input.handle_event(_click())
	assert_true(g.alive)
	assert_eq(refusals.size(), 1)
	assert_eq(_target(dyn), Vector3.ZERO, "no auto-walk into range")
	picked = _ground(Vector3(3, 0, 3))
	input.handle_event(_click())
	assert_true(g.alive)
	assert_eq(refusals.size(), 2, "ground is not a guard")


func test_escape_and_right_click_disarm() -> void:
	input.handle_event(_key(KEY_R))
	assert_eq(input.armed_ability, &"pistol")
	input.handle_event(_key(KEY_ESCAPE))
	assert_eq(input.armed_ability, &"")
	input.handle_event(_key(KEY_R))
	input.handle_event(_click(MOUSE_BUTTON_RIGHT))
	assert_eq(input.armed_ability, &"")
	assert_eq(_target(dyn), Vector3.ZERO)


func test_e_is_charge_for_dynamiter_and_plants_at_feet() -> void:
	input.handle_event(_key(KEY_E))
	assert_eq(get_tree().get_nodes_in_group(PlantedCharge.GROUP).size(), 1)
	assert_eq(input.armed_ability, &"")


func test_e_is_rifle_for_marksman_and_arms() -> void:
	input.handle_event(_key(KEY_2))
	input.handle_event(_key(KEY_E))
	assert_eq(input.armed_ability, &"rifle")


func test_charge_out_of_ammo_is_refused() -> void:
	for i in dyn.abilities["charge"].ammo:
		input.handle_event(_key(KEY_E))
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()
	refusals.clear()
	input.handle_event(_key(KEY_E))
	assert_eq(refusals.size(), 1)
	assert_eq(input.armed_ability, &"")


func test_missing_ability_refused() -> void:
	input.handle_event(_key(KEY_2))
	input.handle_event(_key(KEY_Q))
	assert_eq(input.armed_ability, &"")
	assert_eq(refusals.size(), 1)


func test_f_picks_nearest_body_and_drops() -> void:
	var far := load("res://scenes/units/body.tscn").instantiate() as Body
	add_child_autofree(far)
	far.global_position = Vector3(1.4, 0, 0)
	var near := load("res://scenes/units/body.tscn").instantiate() as Body
	add_child_autofree(near)
	near.global_position = Vector3(0.5, 0, 0)
	input.handle_event(_key(KEY_F))
	assert_eq(dyn.carrying, near)
	input.handle_event(_key(KEY_F))
	assert_null(dyn.carrying)


func test_f_with_no_body_refused() -> void:
	input.handle_event(_key(KEY_F))
	assert_eq(refusals.size(), 1)


func test_dead_cannot_be_selected() -> void:
	mark.take_damage(1000)
	input.select(mark)
	assert_eq(input.selected, dyn)
	input.handle_event(_key(KEY_2))
	assert_eq(input.selected, dyn)


func test_selected_death_selects_survivor() -> void:
	dyn.take_damage(1000)
	assert_eq(input.selected, mark)


func test_space_pauses_and_blocks_orders() -> void:
	watch_signals(input)
	input.handle_event(_key(KEY_SPACE))
	assert_true(get_tree().paused)
	assert_signal_emitted_with_parameters(input, "paused_changed", [true])
	picked = _ground(Vector3(8, 0, 3))
	input.handle_event(_click())
	input.handle_event(_key(KEY_C))
	input.handle_event(_key(KEY_Q))
	assert_eq(_target(dyn), Vector3.ZERO)
	assert_eq(dyn.stance, Unit.Stance.STANDING)
	assert_eq(input.armed_ability, &"")
	input.handle_event(_key(KEY_SPACE))
	assert_false(get_tree().paused)
	assert_signal_emitted_with_parameters(input, "paused_changed", [false])


func test_orders_disabled_refuses() -> void:
	input.orders_enabled = false
	picked = _ground(Vector3(8, 0, 3))
	input.handle_event(_click())
	input.handle_event(_key(KEY_C))
	assert_eq(_target(dyn), Vector3.ZERO)
	assert_eq(dyn.stance, Unit.Stance.STANDING)


func test_camera_and_input_process_while_paused() -> void:
	assert_eq(cam.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(input.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_camera_moves_while_paused() -> void:
	cam.edge_scroll_enabled = true
	input.handle_event(_key(KEY_SPACE))
	var before := cam.focus
	cam.scroll_step(0.5, Vector2(990, 300), Vector2(1000, 600))
	assert_ne(cam.focus, before)
	input.handle_event(_click(MOUSE_BUTTON_WHEEL_UP))
	assert_lt(cam.size, IsoCamera.ZOOM_MAX)


func test_focus_lost_pauses_and_stops_edge_scroll() -> void:
	cam.edge_scroll_enabled = true
	input.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)
	var before := cam.focus
	cam.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	cam.scroll_step(0.5, Vector2(990, 300), Vector2(1000, 600))
	assert_eq(cam.focus, before)
	input.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(get_tree().paused, "focus in does not unpause")


func test_window_focus_out_also_pauses() -> void:
	input.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_true(get_tree().paused)


func test_edge_scroll_margin_and_mouse_exit() -> void:
	cam.edge_scroll_enabled = true
	var size := Vector2(1000, 600)
	assert_eq(cam.edge_scroll_direction(Vector2(500, 300), size), Vector2.ZERO)
	assert_eq(cam.edge_scroll_direction(Vector2(15, 300), size), Vector2(-1, 0))
	assert_eq(cam.edge_scroll_direction(Vector2(500, 590), size), Vector2(0, 1))
	var before := cam.focus
	cam.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	cam.scroll_step(0.5, Vector2(5, 5), size)
	assert_eq(cam.focus, before)
	cam.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	cam.scroll_step(0.5, Vector2(5, 5), size)
	assert_ne(cam.focus, before)


func test_edge_scroll_off_by_default() -> void:
	var before := cam.focus
	cam.scroll_step(0.5, Vector2(5, 5), Vector2(1000, 600))
	assert_eq(cam.focus, before)


func test_picker_hits_unit_then_ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	ground.add_child(shape)
	add_child_autofree(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	ground.collision_layer = Unit.LAYER_WORLD
	cam.pan(Vector2(20, 20))
	dyn.global_position = Vector3(20, 0, 20)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var center := cam.get_viewport().get_visible_rect().size / 2.0
	var hit := Picker.pick(cam, center)
	assert_eq(hit.get("collider"), dyn)
	var off := Picker.pick(cam, center + Vector2(center.x * 0.4, 0))
	assert_eq(off.get("collider"), ground)
	assert_almost_eq((off["position"] as Vector3).y, 0.0, 0.01)


# --- move_ordered: what the order marker listens to ---

func _orders() -> Array:
	var seen: Array = []
	input.move_ordered.connect(func(pos: Vector3, run: bool) -> void: seen.append([pos, run]))
	return seen


func test_a_ground_click_announces_the_move_once() -> void:
	var seen := _orders()
	picked = _ground(Vector3(4, 0, 3))
	input.handle_event(_click())
	assert_eq(seen, [[Vector3(4, 0, 3), false]])


func test_a_double_click_announces_a_run() -> void:
	var seen := _orders()
	picked = _ground(Vector3(4, 0, 3))
	input.handle_event(_click())
	now += 0.1
	input.handle_event(_click())
	assert_eq(seen.size(), 2)
	assert_eq(seen[1], [Vector3(4, 0, 3), true])


func test_no_move_is_announced_for_other_clicks() -> void:
	var seen := _orders()
	picked = { "collider": mark, "position": mark.global_position }
	input.handle_event(_click())  # selects the Marksman
	picked = { "collider": _guard(Vector3(9, 0, 0)), "position": Vector3(9, 0, 0) }
	input.handle_event(_click())  # shows a guard's cone
	input.select(dyn)
	input.handle_event(_key(KEY_Q))  # arms the knife
	picked = _ground(Vector3(4, 0, 3))
	input.handle_event(_click())  # an armed click on bare ground is refused
	input.handle_event(_key(KEY_ESCAPE))
	input.orders_enabled = false
	input.handle_event(_click())  # the mission is over
	input.orders_enabled = true
	input.set_paused(true)
	input.handle_event(_click())  # paused
	assert_eq(seen, [])


# --- Picking a unit that stands behind something ---

func _box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = pos
	return body


func test_a_guard_behind_a_wall_is_still_picked_through_it() -> void:
	cam.current = true
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60))  # the ground
	var guard := _guard(Vector3(20, 0, 0))
	# A wall between the camera and the guard: the camera looks from +x, +z, above.
	var toward_camera := Vector3(cam.global_basis.z.x, 0, cam.global_basis.z.z).normalized()
	var wall := _box(guard.global_position + toward_camera * 2.0 + Vector3.UP * 2.0, Vector3(6, 4, 6))
	await wait_physics_frames(2)
	var on_guard := cam.unproject_position(guard.global_position + Vector3.UP * 0.85)
	var hit := Picker.pick(cam, on_guard)
	assert_eq(hit.get("collider"), guard, "the pointer is on the guard's shape, wall or no wall")
	var beside := cam.unproject_position(wall.global_position + Vector3(0, 2.0, 0) + cam.global_basis.x * 2.5)
	assert_eq(Picker.pick(cam, beside).get("collider"), wall, "beside the guard the wall is what is hit")
	var open_ground := cam.unproject_position(Vector3(-10, 0, -10))
	var ground_hit := Picker.pick(cam, open_ground)
	assert_almost_eq(ground_hit["position"], Vector3(-10, 0, -10), Vector3.ONE * 0.05)
	assert_eq(Picker.pick(cam, on_guard, Unit.LAYER_WORLD).get("collider"), wall, "a world-only pick ignores units")


# --- Camera rotation keys ---

func test_z_and_x_turn_the_camera_even_when_paused_or_after_the_mission() -> void:
	input.handle_event(_key(KEY_X))
	assert_eq(cam.quarter, 1)
	input.handle_event(_key(KEY_Z))
	input.handle_event(_key(KEY_Z))
	assert_eq(cam.quarter, 3)
	input.set_paused(true)
	input.handle_event(_key(KEY_X))
	assert_eq(cam.quarter, 0, "looking round while paused")
	input.set_paused(false)
	input.orders_enabled = false
	input.handle_event(_key(KEY_X))
	assert_eq(cam.quarter, 1)


# --- Bringing the camera to a specialist ---

func test_pressing_the_selected_specialists_key_again_centres_the_camera_on_them() -> void:
	mark.global_position = Vector3(18, 0, -7)
	input.handle_event(_key(KEY_2))
	assert_eq(input.selected, mark)
	assert_ne(Vector2(cam.focus.x, cam.focus.z), Vector2(18, -7), "selecting alone leaves the view where it is")
	input.handle_event(_key(KEY_2))
	assert_almost_eq(Vector2(cam.focus.x, cam.focus.z), Vector2(18, -7), Vector2.ONE * 0.001)
	input.set_paused(true)
	cam.pan(Vector2(5, 5))
	input.handle_event(_key(KEY_2))
	assert_almost_eq(Vector2(cam.focus.x, cam.focus.z), Vector2(18, -7), Vector2.ONE * 0.001, "also while paused")
