class_name GuardMarker
extends Label3D
## The sign above a guard's head: nothing on patrol, "?" when it has noticed something (suspicious
## or investigating), "!" in an alarm. Display only: it reads the guard's brain every frame, so it
## is right after a load as well.

const NOTICED_COLOR := Color(1.0, 0.85, 0.2)
const ALARM_COLOR := Color(1.0, 0.25, 0.2)
const HEIGHT := 2.35

var _guard: Guard


func _ready() -> void:
	_guard = get_parent() as Guard
	position = Vector3(0.0, HEIGHT, 0.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	render_priority = 10
	outline_render_priority = 9
	pixel_size = 0.012
	font_size = 96
	outline_size = 24
	outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	# Runs while paused so a load made during a pause shows at once.
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var sign := ""
	if _guard != null and _guard.alive and _guard.brain != null:
		match _guard.brain.state:
			GuardBrain.State.SUSPICIOUS, GuardBrain.State.INVESTIGATE:
				sign = "?"
				modulate = NOTICED_COLOR
			GuardBrain.State.ALARM:
				sign = "!"
				modulate = ALARM_COLOR
	text = sign
	visible = sign != ""
