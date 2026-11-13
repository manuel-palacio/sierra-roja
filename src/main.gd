extends Node3D
## Loads the mission, validates it and starts the camera. An invalid mission is a
## content bug: debug builds stop with exit code 1, release builds log the errors.

const NIGHT_MOON := Color(0.60, 0.70, 1.0)
const NIGHT_SKY := Color(0.02, 0.03, 0.06)
## A lid of cloud: little sun, a lot of flat light from everywhere, faint shadows.
const OVERCAST := { "sun": Color(0.86, 0.88, 0.92), "sun_energy": 0.55, "fill_energy": 0.45,
		"ambient": Color(0.72, 0.76, 0.84), "ambient_energy": 0.95, "sky": Color(0.62, 0.65, 0.70),
		"saturation": 0.85, "shadow": 0.35 }
## The last of the sun: low and orange, the shadows long and the rest going blue.
const DUSK := { "sun": Color(1.0, 0.62, 0.38), "sun_energy": 0.7, "fill_energy": 0.2,
		"ambient": Color(0.46, 0.44, 0.62), "ambient_energy": 0.7, "sky": Color(0.38, 0.33, 0.42),
		"saturation": 0.9, "shadow": 1.0 }
## How high the dusk sun stands, in degrees.
const DUSK_SUN_HEIGHT := 14.0

## Starts the game again; with another mission chosen in Missions, on that one. Tests replace it.
var reload_action := func() -> void: get_tree().reload_current_scene()

var mission: Mission
var camera: IsoCamera
var specialists: Array[Specialist] = []
var rules: MissionRules
var player_input: PlayerInput
var overlay: VisionOverlay
var charge_display: ChargeDisplay
var hud: Hud
## The opening screen while it is up, else null.
var briefing: Briefing
## Tests set this before the game starts, to have snow fall on a mission that has none.
var force_snowfall := false


func _ready() -> void:
	if PerfProbe.enabled():
		add_child(PerfProbe.new())
	if ScreenProbe.enabled():
		add_child(ScreenProbe.new())
	mission = load(Missions.path()).instantiate()
	add_child(mission)
	apply_light()
	camera = IsoCamera.new()
	camera.bounds = mission.bounds_rect
	camera.size = IsoCamera.ZOOM_START
	add_child(camera)
	var start := mission.specialist_spawns()
	if not start.is_empty():
		camera.pan(Vector2(start[0].global_position.x, start[0].global_position.z))
	# CSG geometry is built on the next idle frame; the nav bake needs it. The physics frame puts
	# the land and the deck in the physics world, which spawns and routes are set down on.
	await get_tree().process_frame
	await get_tree().physics_frame
	mission.build_nav()
	specialists = mission.spawn_specialists()
	if not specialists.is_empty():
		camera.set_ground_level(specialists[0].global_position.y)
	rules = MissionRules.new()
	add_child(rules)
	rules.setup(mission, specialists)
	# A win is remembered before anything is shown of it: it opens the next mission.
	rules.result_changed.connect(func(r: MissionRules.Result) -> void:
		if r == MissionRules.Result.WON:
			Campaign.mark_won(Missions.id_at(Missions.current)))
	player_input = PlayerInput.new()
	add_child(player_input)
	player_input.setup(camera, specialists)  # selects the Dynamiter
	player_input.bind_mission(mission)
	camera.edge_scroll_enabled = true
	rules.result_changed.connect(func(r: MissionRules.Result) -> void:
		player_input.orders_enabled = r == MissionRules.Result.RUNNING)
	var order_marker := OrderMarker.new()
	add_child(order_marker)
	player_input.move_ordered.connect(order_marker.show_at)
	player_input.selection_changed.connect(_show_selection)
	_show_selection(player_input.selected)
	overlay = VisionOverlay.new()
	add_child(overlay)
	hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	add_child(hud)
	hud.setup(player_input, rules, specialists, overlay)
	hud.end_screen.mission_id = Missions.id_at(Missions.current)
	hud.end_screen.offer_next = true
	if not Missions.has_next():
		hud.end_screen.next_button.text = "Back to the missions"
	hud.end_screen.next_pressed.connect(func() -> void:
		go_to_mission(Missions.current + 1 if Missions.has_next() else 0))
	add_child(_vignette())
	var objective_marker := ObjectiveMarker.new()
	add_child(objective_marker)
	objective_marker.setup(camera, mission, rules)
	add_child(SoundEffects.new())
	add_child(ShotDisplay.new())
	charge_display = ChargeDisplay.new()
	add_child(charge_display)
	if mission.snowfall or force_snowfall:
		var snow := Snowfall.new()
		add_child(snow)
		snow.follow(camera)
	SaveGame.message.connect(hud.show_message)
	SaveGame.restart_offered.connect(hud.offer_restart)
	if Briefing.wanted():
		open_briefing()
	var errors := MissionValidator.validate(mission)
	if not errors.is_empty():
		for message in errors:
			push_error("Invalid mission: " + message)
		if OS.is_debug_build():
			get_tree().quit(1)


## Puts up the opening screen. No orders are taken and the view stays on the squad until it is
## started; the mission itself runs on behind it, where the squad's starting place is out of
## every guard's sight.
func open_briefing() -> Briefing:
	briefing = Briefing.new()
	add_child(briefing)
	briefing.set_mission(mission, Missions.current)
	briefing.mission_chosen.connect(go_to_mission)
	player_input.orders_enabled = false
	camera.edge_scroll_enabled = false
	rules.clock_running = false
	briefing.started.connect(func() -> void:
		briefing = null
		rules.clock_running = true
		camera.edge_scroll_enabled = true
		# Losing the window's focus pauses the game; Start means start.
		player_input.set_paused(false)
		player_input.orders_enabled = rules.result == MissionRules.Result.RUNNING)
	return briefing


## Leaves this mission for another one of Missions.LIST, starting with its briefing.
func go_to_mission(index: int) -> void:
	Missions.choose(index)
	Briefing.seen = false
	get_tree().paused = false
	reload_action.call()


func _show_selection(_chosen: Specialist) -> void:
	var chosen := player_input.selected_units()
	for s in specialists:
		var ring := s.get_node_or_null("Ring") as SelectionRing
		if ring != null:
			ring.selected = s in chosen


## A soft darkening of the view's corners, under the HUD.
func _vignette() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/vignette.gdshader")
	rect.material = material
	layer.add_child(rect)
	return layer


## Lights the scene for the mission: night if it is one, else its daylight. The scene as it
## stands is dawn, and an unknown light leaves it so.
func apply_light() -> void:
	if mission.night:
		_fall_night()
	elif mission.light == &"overcast":
		_daylight(OVERCAST)
	elif mission.light == &"dusk":
		_daylight(DUSK)
		var sun := get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			# Keeps its bearing; only comes down towards the horizon.
			sun.rotation.x = -deg_to_rad(DUSK_SUN_HEIGHT)
		_turn_lamps_up(2.0, 12.0)
	elif mission.season == &"snow":
		_set_sky(Terrain.SNOW_MIST, 0.24)


## One of the daylight presets above.
func _daylight(look: Dictionary) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = look["sun"]
		sun.light_energy = look["sun_energy"]
		sun.shadow_opacity = look["shadow"]
	var fill := get_node_or_null("Fill") as DirectionalLight3D
	if fill != null:
		fill.light_energy = look["fill_energy"]
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		world.environment = world.environment.duplicate()
		world.environment.ambient_light_color = look["ambient"]
		world.environment.ambient_light_energy = look["ambient_energy"]
		world.environment.adjustment_saturation = look["saturation"]
	# Under snow the far land is paler than the sky's own colour; over it, the sky's.
	var sky: Color = look["sky"]
	if mission.season == &"snow":
		sky = sky.lerp(Terrain.SNOW_MIST, 0.6) if look == OVERCAST else sky
	# No cloud shadows drift over the land under a lid of cloud, or at dusk.
	_set_sky(sky, 0.0)


## What is seen past the edge of the map, and what the land dissolves into there.
func _set_sky(colour: Color, cloud_shade: float) -> void:
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		if world.environment.background_color != colour:
			world.environment = world.environment.duplicate()
		world.environment.background_color = colour
	if mission.terrain() != null:
		mission.terrain().set_sky(colour, cloud_shade)


## Turns the dawn into a clear night: a low cold moon in place of the sun, little light in the
## shadows, darkness past the edge of the map, and the lamps turned up to matter.
func _fall_night() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = NIGHT_MOON
		sun.light_energy = 0.5
	var fill := get_node_or_null("Fill") as DirectionalLight3D
	if fill != null:
		fill.light_energy = 0.1
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		world.environment = world.environment.duplicate()
		world.environment.background_color = NIGHT_SKY
		world.environment.ambient_light_color = Color(0.26, 0.33, 0.58)
		world.environment.ambient_light_energy = 0.6
		world.environment.adjustment_saturation = 0.8
	if mission.terrain() != null:
		mission.terrain().set_sky(NIGHT_SKY, 0.0)
	_turn_lamps_up(3.2, 13.0)


## Every lamp of the mission at so many times what its scene gives it. Works from the scene's own
## figure each time, so lighting the mission again does not turn them up again.
func _turn_lamps_up(times: float, reach: float) -> void:
	for node in mission.find_children("Lamp*", "OmniLight3D", true, false):
		var lamp := node as OmniLight3D
		if not lamp.has_meta(&"scene_energy"):
			lamp.set_meta(&"scene_energy", lamp.light_energy)
		lamp.light_energy = float(lamp.get_meta(&"scene_energy")) * times
		lamp.omni_range = reach
