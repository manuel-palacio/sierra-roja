extends Node3D
## Loads the mission, validates it and starts the camera. An invalid mission is a
## content bug: debug builds stop with exit code 1, release builds log the errors.

const MISSION_SCENE := "res://scenes/missions/bridge.tscn"

var mission: Mission
var camera: IsoCamera


func _ready() -> void:
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
	var errors := MissionValidator.validate(mission)
	if not errors.is_empty():
		for message in errors:
			push_error("Invalid mission: " + message)
		if OS.is_debug_build():
			get_tree().quit(1)
