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
var charge_display: ChargeDisplay
var hud: Hud
## The opening screen while it is up, else null.
var briefing: Briefing


func _ready() -> void:
	if PerfProbe.enabled():
		add_child(PerfProbe.new())
	if ScreenProbe.enabled():
		add_child(ScreenProbe.new())
	mission = load(MISSION_SCENE).instantiate()
	add_child(mission)
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
	add_child(SoundEffects.new())
	add_child(ShotDisplay.new())
	charge_display = ChargeDisplay.new()
	add_child(charge_display)
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
	player_input.orders_enabled = false
	camera.edge_scroll_enabled = false
	briefing.started.connect(func() -> void:
		briefing = null
		camera.edge_scroll_enabled = true
		player_input.orders_enabled = rules.result == MissionRules.Result.RUNNING)
	return briefing


func _show_selection(chosen: Specialist) -> void:
	for s in specialists:
		var ring := s.get_node_or_null("Ring") as SelectionRing
		if ring != null:
			ring.selected = s == chosen
