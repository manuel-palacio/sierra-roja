class_name MapView
extends Control
## What is drawn over the whole ground while the camera is in its map view (M): each guard as a
## red dot with the beat it walks, the pair as numbered blue dots, and the way out in green.
## Display only: it reads where things are and changes nothing.

const GUARD_COLOR := Color(0.95, 0.25, 0.2)
const BEAT_COLOR := Color(0.95, 0.25, 0.2, 0.55)
const OWN_COLOR := Color(0.35, 0.7, 1.0)
const OUT_COLOR := Color(0.4, 0.85, 0.35)
const DOT := 6.0

var _camera: IsoCamera
var _mission: Mission
var _specialists: Array[Specialist] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(camera: IsoCamera, mission: Mission, specialists: Array[Specialist]) -> void:
	_camera = camera
	_mission = mission
	_specialists = specialists


func _process(_delta: float) -> void:
	visible = _camera != null and _camera.map_view
	if visible:
		queue_redraw()


## Guard -> the points of its beat on the screen, for the guards that walk one.
func beats() -> Dictionary:
	var out := {}
	for guard in _mission.guards():
		if guard.alive and guard.route_size() > 1:
			var points := PackedVector2Array()
			for p in guard.route():
				points.append(_camera.unproject_position(p))
			out[guard] = points
	return out


func _draw() -> void:
	if _camera == null or _mission == null or not _camera.is_inside_tree():
		return
	var routes := beats()
	for guard in routes:
		var points: PackedVector2Array = routes[guard]
		points.append(points[0])
		draw_polyline(points, BEAT_COLOR, 2.0, true)
	for guard in _mission.guards():
		if guard.alive:
			draw_circle(_camera.unproject_position(guard.global_position), DOT, GUARD_COLOR)
	var out := _mission.extraction()
	if out != null:
		var at := _camera.unproject_position(out.global_position)
		draw_rect(Rect2(at - Vector2(DOT, DOT), Vector2(DOT, DOT) * 2.0), OUT_COLOR, false, 3.0)
	for i in _specialists.size():
		if _specialists[i].alive:
			var at := _camera.unproject_position(_specialists[i].global_position)
			draw_circle(at, DOT + 1.0, OWN_COLOR)
			draw_string(UiStyle.FONT, at + Vector2(DOT + 4.0, 5.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, OWN_COLOR)
