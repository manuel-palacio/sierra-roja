extends GutTest
## The small signs that tell the player what is going on: a guard's mood, where an order landed,
## which specialist is selected.


# --- Guard marker ---

func _guard() -> Guard:
	var guard: Guard = load("res://scenes/units/guard.tscn").instantiate()
	add_child_autofree(guard)
	guard.set_physics_process(false)
	return guard


func test_a_patrolling_guard_shows_nothing() -> void:
	var guard := _guard()
	var marker := guard.get_node("Marker") as GuardMarker
	marker.refresh()
	assert_eq(marker.text, "")
	assert_false(marker.visible)


func test_a_guard_that_noticed_something_shows_a_yellow_question_mark() -> void:
	var guard := _guard()
	var marker := guard.get_node("Marker") as GuardMarker
	guard.brain.tick(0.1, Vision.Zone.FAR, Vector3(0, 0, -10), false)
	assert_eq(guard.brain.state, GuardBrain.State.SUSPICIOUS)
	marker.refresh()
	assert_eq(marker.text, "?")
	assert_true(marker.visible)
	assert_eq(marker.modulate, GuardMarker.NOTICED_COLOR)


func test_an_investigating_guard_keeps_the_question_mark() -> void:
	var guard := _guard()
	var marker := guard.get_node("Marker") as GuardMarker
	guard.brain.hear(Vector3(5, 0, 5))
	assert_eq(guard.brain.state, GuardBrain.State.INVESTIGATE)
	marker.refresh()
	assert_eq(marker.text, "?")
	assert_eq(marker.modulate, GuardMarker.NOTICED_COLOR)


func test_an_alarmed_guard_shows_a_red_exclamation_mark() -> void:
	var guard := _guard()
	var marker := guard.get_node("Marker") as GuardMarker
	guard.brain.on_alarm(Vector3(5, 0, 5))
	assert_eq(guard.brain.state, GuardBrain.State.ALARM)
	marker.refresh()
	assert_eq(marker.text, "!")
	assert_eq(marker.modulate, GuardMarker.ALARM_COLOR)


func test_the_marker_follows_a_load_back_to_patrol() -> void:
	var guard := _guard()
	var marker := guard.get_node("Marker") as GuardMarker
	var calm := guard.save_state()
	guard.brain.on_alarm(Vector3(5, 0, 5))
	marker.refresh()
	assert_eq(marker.text, "!")
	guard.load_state(calm)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(marker.text, "", "it reads the state each frame, so a load needs no signal")
	assert_false(marker.visible)


func test_the_marker_is_readable_from_the_fixed_camera() -> void:
	var marker := _guard().get_node("Marker") as GuardMarker
	assert_eq(marker.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_true(marker.no_depth_test, "shows over trees and roofs")
	assert_gt(marker.position.y, 1.9, "above the head")
	assert_eq(marker.process_mode, Node.PROCESS_MODE_ALWAYS, "keeps up while paused")


# --- Order marker ---

func test_an_idle_order_marker_does_nothing_each_frame() -> void:
	var marker := OrderMarker.new()
	add_child_autofree(marker)
	assert_false(marker.is_processing(), "nothing to animate before the first order")
	marker._process(0.1)  # and a stray call is harmless
	assert_eq(marker.get_child_count(), 0)


func test_an_order_marker_shows_one_ring_for_a_walk_and_two_for_a_run() -> void:
	var marker := OrderMarker.new()
	add_child_autofree(marker)
	marker.show_at(Vector3(3, 1, 4), false)
	assert_eq(marker.get_child_count(), 1)
	assert_almost_eq((marker.get_child(0) as Node3D).global_position, Vector3(3, 1 + OrderMarker.LIFT, 4), Vector3.ONE * 0.001)
	marker.show_at(Vector3(8, 0, 0), true)
	assert_eq(marker.get_child_count(), 2, "the walk's ring is replaced by the run's two")


func test_an_order_marker_shrinks_then_goes() -> void:
	var marker := OrderMarker.new()
	add_child_autofree(marker)
	marker.show_at(Vector3.ZERO, false)
	var ring := marker.get_child(0) as Node3D
	var at_start := ring.scale.x
	marker._process(OrderMarker.DURATION / 2.0)
	assert_lt(ring.scale.x, at_start, "shrinking")
	marker._process(OrderMarker.DURATION / 2.0 + 0.01)
	await get_tree().process_frame
	assert_eq(marker.get_child_count(), 0, "gone after %s s" % OrderMarker.DURATION)


# --- Selection ring ---

func test_the_selected_ring_is_bright_and_pulses_and_the_other_is_dim() -> void:
	var unit: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	add_child_autofree(unit)
	unit.set_physics_process(false)
	var ring := unit.get_node("Ring") as SelectionRing
	ring.selected = false
	ring._process(0.1)
	assert_almost_eq(ring.material_override.albedo_color.a, SelectionRing.DIM_ALPHA, 0.001)
	assert_eq(ring.scale, Vector3.ONE)
	ring.selected = true
	var sizes := {}
	for i in 20:
		ring._process(0.1)
		sizes[snappedf(ring.scale.x, 0.01)] = true
	assert_almost_eq(ring.material_override.albedo_color.a, 1.0, 0.001)
	assert_gt(sizes.size(), 3, "its size keeps changing")
	assert_true(ring.material_override.no_depth_test, "seen through whatever stands in front")


func test_each_specialist_keeps_its_own_ring_colour() -> void:
	var a: Specialist = load("res://scenes/units/specialist.tscn").instantiate()
	var b: Specialist = load("res://scenes/units/marksman.tscn").instantiate()
	add_child_autofree(a)
	add_child_autofree(b)
	var ca: Color = (a.get_node("Ring") as SelectionRing).color
	var cb: Color = (b.get_node("Ring") as SelectionRing).color
	assert_ne(ca, cb)


# --- Wired into the game ---

func test_the_game_lights_the_selected_ring_and_marks_an_order() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	var rings: Array[SelectionRing] = []
	for s in main.specialists:
		rings.append(s.get_node("Ring") as SelectionRing)
	assert_true(rings[0].selected, "the Dynamiter starts selected")
	assert_false(rings[1].selected)
	main.player_input.select(main.specialists[1])
	assert_false(rings[0].selected)
	assert_true(rings[1].selected)
	var marker := main.find_children("*", "OrderMarker", true, false)[0] as OrderMarker
	var spot: Vector3 = main.specialists[1].global_position + Vector3(3, 0, 0)
	main.player_input.picker = func(_pos: Vector2) -> Dictionary: return { "collider": null, "position": spot }
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.player_input.handle_event(click)
	assert_eq(marker.get_child_count(), 1, "one ring where the order landed")
	get_tree().paused = false
