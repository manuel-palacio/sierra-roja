class_name ObjectiveMarker
extends CanvasLayer
## Points the player at the current objective: the bridge until it is down, then the extraction.
## On screen it hangs an arrow over the place; off screen it sits at the edge of the view,
## pointing the way and saying how far. Display only; hidden once the mission has ended.

const EDGE_MARGIN := 56.0
const COLOR := Color(1.0, 0.86, 0.35)
const EXTRACTION_TEXT := "Extraction"
## The on-screen arrow hangs this far above the place, in pixels, and bobs by a few more.
const HANG := 46.0
const BOB := 5.0

var label: Label
var arrow: Polygon2D
## World position of the objective pointed at.
var target := Vector3.ZERO
var on_screen := false

var _camera: IsoCamera
var _mission: Mission
var _rules: MissionRules
var _time := 0.0


func _init() -> void:
	layer = 0
	process_mode = Node.PROCESS_MODE_ALWAYS
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(14, 0), Vector2(-9, -10), Vector2(-4, 0), Vector2(-9, 10)])
	arrow.color = COLOR
	add_child(arrow)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func setup(camera: IsoCamera, mission: Mission, rules: MissionRules) -> void:
	_camera = camera
	_mission = mission
	_rules = rules


## Where to draw for a target at a screen position: in place when it is comfortably in view,
## else on the edge of the view along the line from the centre, with the angle to point at.
static func placement(screen_pos: Vector2, view: Vector2) -> Dictionary:
	# In a very small window the margin shrinks with it.
	var margin := minf(EDGE_MARGIN, minf(view.x, view.y) / 4.0)
	var inner := Rect2(Vector2.ONE * margin, view - Vector2.ONE * margin * 2.0)
	if inner.has_point(screen_pos):
		return { "on_screen": true, "at": screen_pos, "angle": PI / 2.0 }
	var centre := view / 2.0
	var toward := screen_pos - centre
	var half := inner.size / 2.0
	var scale := minf(half.x / maxf(absf(toward.x), 0.001), half.y / maxf(absf(toward.y), 0.001))
	return { "on_screen": false, "at": centre + toward * scale, "angle": toward.angle() }


func _process(delta: float) -> void:
	_time += delta
	if _rules == null or _rules.result != MissionRules.Result.RUNNING:
		visible = false
		return
	var place: Node3D = _mission.extraction() if _rules.bridge_destroyed else _mission.bridge_target()
	if place == null or not _camera.is_inside_tree():
		visible = false
		return
	visible = true
	target = place.global_position
	if _rules.bridge_destroyed:
		target.y = _mission.ground_height(target.x, target.z)
	var name_text := EXTRACTION_TEXT if _rules.bridge_destroyed else _mission.target_name
	var view := _camera.get_viewport().get_visible_rect().size
	var p := placement(_camera.unproject_position(target), view)
	on_screen = p["on_screen"]
	var at: Vector2 = p["at"]
	if on_screen:
		at.y -= HANG + sin(_time * 4.0) * BOB
		label.text = name_text
	else:
		var away := Vector2(target.x - _camera.focus.x, target.z - _camera.focus.z).length()
		label.text = "%s %d m" % [name_text, int(roundf(away))]
	arrow.position = at
	arrow.rotation = p["angle"]
	var size := label.get_minimum_size()
	# The name sits on the inward side of the arrow, kept inside the view.
	var inward := (view / 2.0 - at).normalized() if not on_screen else Vector2.UP
	var clear := 20.0 + maxf(size.x * absf(inward.x), size.y * absf(inward.y)) / 2.0
	var spot := at + inward * clear - size / 2.0
	label.position = Vector2(clampf(spot.x, 4.0, view.x - size.x - 4.0), clampf(spot.y, 4.0, view.y - size.y - 4.0))
