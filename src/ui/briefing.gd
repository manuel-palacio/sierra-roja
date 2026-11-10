class_name Briefing
extends CanvasLayer
## The opening screen: what the mission is, the controls, and a Start button. While it is up it
## takes every click and key press, so nothing reaches the game; Enter or Space start as well.
## Display only: whoever opens it decides what `started` means.

signal started()

const TITLE := "Sierra Roja"
const SUBTITLE := "The bridge at night"
const OBJECTIVES: Array[String] = [
	"Destroy the railway bridge with the Dynamiter's charge.",
	"Get both of them to the extraction point on the far bank.",
	"Lose either one and the mission fails.",
]
## Input, then what it does.
const CONTROLS: Array[Array] = [
	["Left click", "Move the selected specialist"],
	["Double-click", "Run (the Dynamiter's boots are heard)"],
	["1 / 2, or click one", "Select the Dynamiter / the Marksman"],
	["Click a guard", "Show what it can see: red even crawling, yellow standing"],
	["C", "Crawl / stand"],
	["Q", "Knife (Dynamiter), then click a guard"],
	["E", "Charge at your feet (Dynamiter) / Rifle (Marksman)"],
	["R", "Pistol, then click a guard"],
	["F", "Carry or drop a body (Dynamiter)"],
	["Space", "Pause and look around"],
	["O / L", "Quick save / quick load"],
	["Z / X", "Turn the camera"],
	["Mouse wheel, screen edges", "Zoom, scroll"],
]

## Set by the first start, and kept for the session: a mission restart goes straight to the game.
static var seen := false

var title_label: Label
var start_button: Button

var _done := false


## False once it has been started in this session, and where a person is not the one starting
## the game: test runs and the browser probes
## (?probe=1, ?perf=1). ?briefing=1 puts it up all the same, for the browser test of the briefing.
static func wanted() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if OS.has_feature("web") and str(JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('briefing')", true)) == "1":
		return true
	return not seen and not PerfProbe.enabled() and not ScreenProbe.enabled()


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks stop here
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	style.border_color = Color(0.55, 0.16, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	title_label = _text(TITLE, 36, Color(0.92, 0.3, 0.22))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	var subtitle := _text(SUBTITLE, 19, Color(0.8, 0.82, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(HSeparator.new())
	for line in OBJECTIVES:
		column.add_child(_text("•  " + line, 16, Color.WHITE))
	column.add_child(HSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 1)
	column.add_child(grid)
	for row in CONTROLS:
		grid.add_child(_text(row[0], 14, Color(1.0, 0.85, 0.55)))
		grid.add_child(_text(row[1], 14, Color(0.86, 0.88, 0.92)))
	start_button = Button.new()
	start_button.text = "Start"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.custom_minimum_size = Vector2(220, 42)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(begin)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	column.add_child(start_button)
	var hint := _text("Enter or Space also start  ·  Credits and licences: /credits.txt", 13, Color(0.6, 0.63, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _input(event: InputEvent) -> void:
	if _done or not event is InputEventKey:
		return
	var key := event as InputEventKey
	# Every key stops here, so none saves, selects or pauses behind the briefing.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	if key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		begin()


## Closes the briefing and says so, once.
func begin() -> void:
	if _done:
		return
	_done = true
	seen = true
	visible = false
	started.emit()
	queue_free()


static func _text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
