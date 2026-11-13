extends GutTest
## Night missions: dark, lamp-lit, with a searchlight on every watchtower. Carchuna is the one
## there is.

const DAY := "res://scenes/missions/bridge.tscn"
const NIGHT := "res://scenes/missions/carchuna.tscn"


func after_each() -> void:
	Missions.current = 0
	Briefing.seen = false
	get_tree().paused = false


func _built(scene: String) -> Mission:
	var mission: Mission = load(scene).instantiate()
	mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().physics_frame
	mission.build_nav()
	await wait_physics_frames(2)
	return mission


func _towers(mission: Mission) -> Array[Watchtower]:
	var out: Array[Watchtower] = []
	for node in mission.find_children("*", "StaticBody3D", true, false):
		if node is Watchtower:
			out.append(node)
	return out


func test_a_night_mission_has_the_lights_on_and_a_day_one_has_not() -> void:
	var mission := await _built(NIGHT)
	assert_true(mission.night)
	assert_eq(MissionValidator.validate(mission), PackedStringArray())
	for tower in _towers(mission):
		assert_not_null(tower.searchlight, "a searchlight on the tower")
	assert_gt(_towers(mission).size(), 0)
	mission.free()
	var day := await _built(DAY)
	assert_false(day.night)
	for tower in _towers(day):
		assert_null(tower.searchlight, "no searchlight by day")


func test_the_beam_swings_back_and_forth_within_its_arc_and_reach() -> void:
	var mission := await _built(NIGHT)
	var tower := _towers(mission)[0]
	var light := tower.searchlight
	light.set_physics_process(false)
	var headings := []
	for i in 100:
		light.sweep(light.period / 100.0)
		var out := light.spot - light.global_position
		assert_almost_eq(Vector2(out.x, out.z).length(), light.reach, 0.01, "the spot rides at its reach")
		assert_almost_eq(light.spot.y, mission.ground_height(light.spot.x, light.spot.z), 0.01, "on the ground")
		headings.append(rad_to_deg(atan2(out.z, out.x)))
	assert_almost_eq(headings.min(), light.aim_deg - light.arc_deg, 1.0)
	assert_almost_eq(headings.max(), light.aim_deg + light.arc_deg, 1.0)


func test_someone_standing_in_the_beam_raises_the_alarm_and_someone_lying_does_not() -> void:
	var mission := await _built(NIGHT)
	var light := _towers(mission)[0].searchlight
	light.set_physics_process(false)
	var specialists := mission.spawn_specialists()
	light.arc_deg = 0.0  # hold the beam still, so that time passing does not move the spot away
	var caught: Array = []
	light.caught.connect(func(s: Unit, _at: Vector3) -> void: caught.append(s))
	light.sweep(0.0)
	var in_spot := light.spot + Vector3(1.0, 0, 0.5)
	specialists[0].global_position = Vector3(in_spot.x, mission.ground_height(in_spot.x, in_spot.z), in_spot.z)
	specialists[0].set_stance(Unit.Stance.CRAWLING)
	await wait_physics_frames(2)
	light.sweep(0.0)
	assert_eq(caught, [], "lying down, the beam passes over")
	for guard in mission.guards():
		assert_eq(guard.brain.state, GuardBrain.State.PATROL)
	specialists[0].set_stance(Unit.Stance.STANDING)
	light.sweep(0.0)
	assert_eq(caught, [specialists[0]])
	for guard in mission.guards():
		assert_eq(guard.brain.state, GuardBrain.State.ALARM, "%s is sent there" % guard.name)
		assert_almost_eq(guard.brain.goal_pos, specialists[0].global_position, Vector3.ONE * 0.01)
	light.sweep(0.1)
	assert_eq(caught.size(), 1, "not again at once")
	light.sweep(Searchlight.COOLDOWN)
	assert_eq(caught.size(), 2, "but again while they stand there")


func test_outside_the_spot_or_behind_something_nobody_is_caught() -> void:
	var mission := await _built(NIGHT)
	var light := _towers(mission)[0].searchlight
	light.set_physics_process(false)
	var s: Specialist = mission.spawn_specialists()[0]
	light.sweep(0.0)
	var beside := light.spot + Vector3(Searchlight.SPOT + 1.5, 0, 0)
	s.global_position = Vector3(beside.x, mission.ground_height(beside.x, beside.z), beside.z)
	await wait_physics_frames(2)
	assert_false(light.catches(s), "outside the lit spot")
	s.global_position = Vector3(light.spot.x, mission.ground_height(light.spot.x, light.spot.z), light.spot.z)
	assert_true(light.catches(s), "in it, in the open")
	# A wall between the lamp and the spot.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(8, 12, 8)
	wall.add_child(shape)
	mission.add_child(wall)
	wall.global_position = light.global_position.lerp(light.spot, 0.6)
	await wait_physics_frames(2)
	assert_false(light.catches(s), "hidden from the lamp")
	s.take_damage(1000)
	assert_false(light.catches(s))


func _game(mission_index: int) -> Node:
	Missions.choose(mission_index)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	while main.hud == null:
		await get_tree().process_frame
	main.mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	return main


func test_the_game_goes_dark_for_a_night_mission_and_not_for_a_day_one() -> void:
	var day := await _game(0)
	var day_sun: float = (day.get_node("Sun") as DirectionalLight3D).light_energy
	var day_sky: Color = (day.get_node("WorldEnvironment") as WorldEnvironment).environment.background_color
	var day_lamp: float = (day.mission.get_node("Scenery/Lamp1") as OmniLight3D).light_energy
	day.free()
	var night := await _game(Missions.index_of("carchuna"))
	assert_true(night.mission.night)
	assert_lt((night.get_node("Sun") as DirectionalLight3D).light_energy, day_sun * 0.5, "a moon, not a sun")
	var night_sky: Color = (night.get_node("WorldEnvironment") as WorldEnvironment).environment.background_color
	assert_lt(night_sky.get_luminance(), day_sky.get_luminance() * 0.2)
	assert_gt((night.mission.get_node("Scenery/Lamp1") as OmniLight3D).light_energy, day_lamp * 2.0, "lamps that matter")
	assert_eq(night.hud.objective_label.text, "Objective: Free the officer")


# --- Daylight other than dawn ---

func _sun(main: Node) -> DirectionalLight3D:
	return main.get_node("Sun") as DirectionalLight3D


func _env(main: Node) -> Environment:
	return (main.get_node("WorldEnvironment") as WorldEnvironment).environment


func test_an_overcast_mission_is_dimmer_and_flatter_than_dawn_and_not_dark() -> void:
	var main := await _game(0)
	var dawn_sun := _sun(main).light_energy
	var dawn_ambient := _env(main).ambient_light_energy
	main.mission.light = &"overcast"
	main.apply_light()
	assert_lt(_sun(main).light_energy, dawn_sun)
	assert_gt(_env(main).ambient_light_energy, dawn_ambient)
	assert_gt(_env(main).background_color.get_luminance(), 0.5)
	assert_lt(_sun(main).shadow_opacity, 0.5, "soft, faint shadows")


func test_dusk_is_warm_and_low_with_lamps_up() -> void:
	var main := await _game(0)
	var day_lamp: float = (main.mission.get_node("Scenery/Lamp1") as OmniLight3D).light_energy
	main.mission.light = &"dusk"
	main.apply_light()
	var colour := _sun(main).light_color
	assert_gt(colour.r, colour.b + 0.3, "an orange sun")
	var height := rad_to_deg(asin(clampf(_sun(main).global_basis.z.y, -1.0, 1.0)))
	assert_between(height, 10.0, 20.0, "low over the horizon, for long shadows")
	assert_almost_eq((main.mission.get_node("Scenery/Lamp1") as OmniLight3D).light_energy, day_lamp * 2.0, 0.001)
	assert_between(_env(main).background_color.get_luminance(), 0.15, 0.5)


func test_night_wins_over_light() -> void:
	var main := await _game(0)
	main.mission.night = true
	main.mission.light = &"dusk"
	main.apply_light()
	assert_almost_eq(_sun(main).light_energy, 0.5, 0.001, "the moon")
	assert_lt(_env(main).background_color.get_luminance(), 0.1)


func test_an_unknown_light_is_dawn() -> void:
	var main := await _game(0)
	var sun := _sun(main).light_energy
	var sky := _env(main).background_color
	main.mission.light = &"aurora"
	main.apply_light()
	assert_eq(_sun(main).light_energy, sun)
	assert_eq(_env(main).background_color, sky)


func test_snow_under_a_dawn_sky_fades_into_snow_mist() -> void:
	var main := await _game(0)
	main.mission.season = &"snow"
	main.mission.terrain().set_season(&"snow")
	main.apply_light()
	assert_eq(_env(main).background_color, Terrain.SNOW_MIST)


func test_lighting_twice_is_lighting_once() -> void:
	var main := await _game(0)
	var lamp := main.mission.get_node("Scenery/Lamp1") as OmniLight3D
	var day_lamp := lamp.light_energy
	main.mission.light = &"dusk"
	main.apply_light()
	main.apply_light()
	assert_almost_eq(lamp.light_energy, day_lamp * 2.0, 0.001)
	main.mission.night = true
	main.apply_light()
	main.apply_light()
	assert_almost_eq(lamp.light_energy, day_lamp * 3.2, 0.001, "and night works from the scene's lamps, not from dusk's")
