extends Node3D
## Loads the mission, validates it and starts the camera. An invalid mission is a
## content bug: debug builds stop with exit code 1, release builds log the errors.

const MISSION_SCENE := "res://scenes/missions/bridge.tscn"

var mission: Mission
var camera: IsoCamera
var specialists: Array[Specialist] = []
var rules: MissionRules
var player_input: PlayerInput
var overlay: VisionOverlay
var hud: Hud


func _ready() -> void:
	if PerfProbe.enabled():
		add_child(PerfProbe.new())
	if ScreenProbe.enabled():
		add_child(ScreenProbe.new())
	mission = load(MISSION_SCENE).instantiate()
	add_child(mission)
	camera = IsoCamera.new()
	camera.bounds = mission.bounds_rect
	add_child(camera)
	var start := mission.specialist_spawns()
	if not start.is_empty():
		camera.pan(Vector2(start[0].global_position.x, start[0].global_position.z))
	# CSG geometry is built on the next idle frame; the nav bake needs it.
	await get_tree().process_frame
	mission.build_nav()
	specialists = mission.spawn_specialists()
	rules = MissionRules.new()
	add_child(rules)
	rules.setup(mission, specialists)
	player_input = PlayerInput.new()
	add_child(player_input)
	player_input.setup(camera, specialists)  # selects the Dynamiter
	player_input.bind_mission(mission)
	camera.edge_scroll_enabled = true
	rules.result_changed.connect(func(r: MissionRules.Result) -> void:
		player_input.orders_enabled = r == MissionRules.Result.RUNNING)
	overlay = VisionOverlay.new()
	add_child(overlay)
	hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Hud
	add_child(hud)
	hud.setup(player_input, rules, specialists, overlay)
	add_child(SoundEffects.new())
	SaveGame.message.connect(hud.show_message)
	SaveGame.restart_offered.connect(hud.offer_restart)
	var errors := MissionValidator.validate(mission)
	if not errors.is_empty():
		for message in errors:
			push_error("Invalid mission: " + message)
		if OS.is_debug_build():
			get_tree().quit(1)
