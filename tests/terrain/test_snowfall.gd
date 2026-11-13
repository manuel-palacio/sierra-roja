extends GutTest
## Falling snow: a capped handful of flakes that rides with the camera. Display only.


func after_each() -> void:
	Missions.current = 0
	Briefing.seen = false
	get_tree().paused = false


func _snow() -> Snowfall:
	var snow := Snowfall.new()
	add_child_autofree(snow)
	return snow


func test_it_never_exceeds_its_cap() -> void:
	var snow := _snow()
	assert_gt(snow.amount, 50)
	assert_lte(snow.amount, Snowfall.MAX_FLAKES)
	assert_lte(Snowfall.MAX_FLAKES, 300, "kept small for the browser")


func test_it_rides_with_the_camera() -> void:
	var snow := _snow()
	var camera := IsoCamera.new()
	add_child_autofree(camera)
	snow.follow(camera)
	camera.centre_on(Vector3(30, 2, -12))
	await wait_process_frames(2)
	assert_almost_eq(snow.global_position.x, camera.focus.x, 0.1)
	assert_almost_eq(snow.global_position.z, camera.focus.z, 0.1)
	assert_gt(snow.global_position.y, camera.focus.y + 10.0, "well above what is looked at")


func test_it_casts_no_shadow_and_stops_nothing() -> void:
	var snow := _snow()
	assert_eq(snow.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(snow.find_children("*", "CollisionObject3D", true, false).size(), 0)


func _game(snowing: bool) -> Node:
	Missions.choose(0)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.force_snowfall = snowing
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	return main


func test_a_mission_without_snowfall_has_none() -> void:
	var main := await _game(false)
	assert_false(main.mission.snowfall)
	assert_eq(main.find_children("*", "Snowfall", true, false).size(), 0)


func test_a_mission_with_snowfall_has_one_following_the_camera() -> void:
	var main := await _game(true)
	var found := main.find_children("*", "Snowfall", true, false)
	assert_eq(found.size(), 1)


func test_it_covers_the_view_however_far_the_camera_is_out() -> void:
	var snow := _snow()
	var camera := IsoCamera.new()
	add_child_autofree(camera)
	snow.follow(camera)
	for zoom in [IsoCamera.ZOOM_START, IsoCamera.ZOOM_MAX]:
		camera.size = zoom
		await wait_process_frames(2)
		# The view is `size` metres high and wider than that; turned any way, it fits in the box.
		assert_gte(snow.emission_box_extents.x, zoom * 1.1, "at zoom %s" % zoom)
		assert_gte(snow.emission_box_extents.z, zoom * 1.1, "at zoom %s" % zoom)
	assert_lte(snow.amount, Snowfall.MAX_FLAKES, "and still no more flakes than the cap")


func test_it_goes_on_falling_while_the_game_is_paused() -> void:
	assert_eq(_snow().process_mode, Node.PROCESS_MODE_ALWAYS)
