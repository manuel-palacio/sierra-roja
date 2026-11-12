extends GutTest
## The pointer to the current objective.

const VIEW := Vector2(1280, 800)


func test_a_target_on_screen_is_marked_where_it_is() -> void:
	var p := ObjectiveMarker.placement(Vector2(400, 300), VIEW)
	assert_true(p["on_screen"])
	assert_eq(p["at"], Vector2(400, 300))


func test_a_target_off_screen_is_pointed_at_from_the_edge() -> void:
	var right := ObjectiveMarker.placement(Vector2(3000, 400), VIEW)
	assert_false(right["on_screen"])
	assert_almost_eq((right["at"] as Vector2).x, VIEW.x - ObjectiveMarker.EDGE_MARGIN, 0.01)
	assert_almost_eq((right["at"] as Vector2).y, 400.0, 0.01, "level with the centre: straight to the right")
	assert_almost_eq(right["angle"], 0.0, 0.001)
	var up_left := ObjectiveMarker.placement(Vector2(-2000, -1200), VIEW)
	assert_false(up_left["on_screen"])
	var at: Vector2 = up_left["at"]
	assert_true(at.x >= ObjectiveMarker.EDGE_MARGIN - 0.01 and at.y >= ObjectiveMarker.EDGE_MARGIN - 0.01)
	assert_true(at.x < VIEW.x / 2.0 and at.y < VIEW.y / 2.0, "toward the top left")
	var toward := Vector2(-2000, -1200) - VIEW / 2.0
	assert_almost_eq(up_left["angle"], toward.angle(), 0.001, "the arrow points at the target")
	assert_almost_eq((at - VIEW / 2.0).angle(), toward.angle(), 0.01, "and sits on the line to it")


func test_a_target_just_inside_the_margin_counts_as_off_screen() -> void:
	var p := ObjectiveMarker.placement(Vector2(VIEW.x - 5, 400), VIEW)
	assert_false(p["on_screen"], "too near the edge to mark in place")


func _game() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	return main


func test_it_points_at_the_bridge_then_the_extraction_then_goes() -> void:
	var main := await _game()
	var marker := main.find_children("*", "ObjectiveMarker", true, false)[0] as ObjectiveMarker
	marker._process(0.0)
	assert_true(marker.visible)
	assert_eq(marker.label.text.split(" ")[0], "Bridge")
	assert_eq(marker.target, (main.mission.get_node("BridgeTarget") as Node3D).global_position)
	main.rules.mission().objectives()[0].done = true
	marker._process(0.0)
	assert_eq(marker.label.text.split(" ")[0], "Extraction")
	assert_almost_eq(marker.target.x, main.mission.extraction().global_position.x, 0.01)
	main.rules.result = MissionRules.Result.WON
	marker._process(0.0)
	assert_false(marker.visible)
	get_tree().paused = false


func test_far_off_it_says_how_far() -> void:
	var main := await _game()
	var marker := main.find_children("*", "ObjectiveMarker", true, false)[0] as ObjectiveMarker
	marker._process(0.0)
	assert_false(marker.on_screen, "the bridge is 50 m from the start")
	assert_string_contains(marker.label.text, " m")
	var metres := int(marker.label.text.split(" ")[1])
	assert_between(metres, 40, 75)
	get_tree().paused = false
