class_name Briefing
extends CanvasLayer
## The opening screen: what the mission is, the controls, and a Start button. While it is up it
## takes every click and key press, so nothing reaches the game; Enter or Space start as well.
## Display only: whoever opens it decides what `started` means.

signal started()
## Another mission was picked from the row of missions: its index in Missions.LIST.
signal mission_chosen(index: int)

const TITLE := "Sierra Roja"
## How wide the note and the objectives run before they wrap, beside the controls.
const TEXT_WIDTH := 470.0
## Input, then what it does.
const CONTROLS: Array[Array] = [
	["Left click", "Move the selected specialist"],
	["Double-click", "Run (the Dynamiter's boots are heard)"],
	["1 / 2, or click one", "Select the Dynamiter / the Marksman (again: find them)"],
	["3", "Select both: they move and crawl together"],
	["Click a guard", "Show what it can see: red even crawling, yellow standing"],
	["C", "Crawl / stand"],
	["Q", "Knife (Dynamiter), then click a guard"],
	["E", "Charge at your feet (Dynamiter) / Rifle (Marksman)"],
	["R", "Pistol, then click a guard"],
	["T", "Throw a stone: click where; guards in earshot go and look"],
	["F", "Use, take, put down or cut. Carry or drop a body (Dynamiter)"],
	["Space", "Pause and look around"],
	["O / L", "Quick save / quick load"],
	["Z / X", "Turn the camera"],
	["Mouse wheel, screen edges", "Zoom, scroll"],
]
## The same, told to someone playing with fingers (see Touch).
const TOUCH_CONTROLS: Array[Array] = [
	["Tap", "Move the selected specialist"],
	["Double tap", "Run (the Dynamiter's boots are heard)"],
	["Tap one of them", "Select the Dynamiter or the Marksman"],
	["Tap a guard", "Show what it can see: red even crawling, yellow standing"],
	["Drag", "Scroll the view"],
	["Two fingers", "Pinch to zoom, twist to turn the camera"],
	["Pictures, bottom right", "Knife, charge, pistol, rifle, carry, stone"],
	["", "Tap one, then its target. A stone brings guards to look"],
	["Buttons, top right", "Both, crawl, use, save, load, pause"],
]
const KEYS_HINT := "Enter or Space also start  ·  Credits and licences: /credits.txt"
const TOUCH_HINT := "Credits and licences: /credits.txt"

## Set by the first start, and kept for the session: a mission restart goes straight to the game.
static var seen := false

var title_label: Label
var start_button: Button
## One per mission in Missions.LIST. The one being played is disabled, and so is any the campaign
## has not opened yet.
var mission_buttons: Array[Button] = []
## What history says of the mission shown; hidden when it has no note.
var note_label: Label

## Switches to the other language, and is named for it in that language.
var language_button: Button

## Goes round the levels of Difficulty, and names the one in force.
var difficulty_button: Button
## The best win of the mission shown; hidden until there is one.
var best_label: Label

var _mission: Mission
var _index := -1
var _subtitle: Label
var _objective_box: VBoxContainer

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
	var style := UiStyle.box(UiStyle.PANEL_DEEP, UiStyle.BRASS, 2, 20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	title_label = _text(TITLE, 36, Color(0.92, 0.3, 0.22))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	_subtitle = _text("", 19, Color(0.8, 0.82, 0.9))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	best_label = _text("", 14, UiStyle.BRASS_BRIGHT)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.visible = false
	column.add_child(best_label)
	var missions := GridContainer.new()
	missions.columns = 3
	missions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	missions.add_theme_constant_override("h_separation", 8)
	missions.add_theme_constant_override("v_separation", 6)
	column.add_child(missions)
	for i in Missions.LIST.size():
		var entry: Dictionary = Missions.LIST[i]
		var button := UiStyle.button(Button.new(), 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: mission_chosen.emit(i))
		missions.add_child(button)
		mission_buttons.append(button)
	var choices := HBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choices.add_theme_constant_override("separation", 8)
	column.add_child(choices)
	language_button = UiStyle.button(Button.new(), 13)
	language_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_button.pressed.connect(func() -> void: Language.choose(Language.other()))
	choices.add_child(language_button)
	difficulty_button = UiStyle.button(Button.new(), 13)
	difficulty_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	difficulty_button.pressed.connect(func() -> void:
		Difficulty.choose(Difficulty.next())
		_word_missions())
	choices.add_child(difficulty_button)
	_word_missions()
	column.add_child(HSeparator.new())
	# The mission on the left, the controls on the right: one above the other is too tall for a
	# small window once a mission has its history to tell.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	column.add_child(body)
	var words := VBoxContainer.new()
	words.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	words.add_theme_constant_override("separation", 10)
	body.add_child(words)
	note_label = _text("", 14, Color(0.86, 0.84, 0.74))
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	note_label.visible = false
	words.add_child(note_label)
	_objective_box = VBoxContainer.new()
	_objective_box.add_theme_constant_override("separation", 6)
	words.add_child(_objective_box)
	body.add_child(VSeparator.new())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 1)
	body.add_child(grid)
	for row in (TOUCH_CONTROLS if Touch.active() else CONTROLS):
		grid.add_child(_text(row[0], 14, Color(1.0, 0.85, 0.55)))
		grid.add_child(_text(row[1], 14, Color(0.86, 0.88, 0.92)))
	start_button = UiStyle.button(Button.new(), 22)
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(220, 42)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(begin)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	column.add_child(start_button)
	var hint := _text(TOUCH_HINT if Touch.active() else KEYS_HINT, 13, Color(0.6, 0.63, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Shows a mission's own title, history and objectives, and marks it in the list of missions.
func set_mission(mission: Mission, index: int) -> void:
	_mission = mission
	_index = index
	_subtitle.text = mission.title
	note_label.text = History.before(Missions.id_at(index))
	note_label.visible = note_label.text != ""
	_show_objectives(mission.briefing_lines)
	_word_missions()
	for i in mission_buttons.size():
		mission_buttons[i].disabled = i == index or not Campaign.is_open(i)
		# Neither can be pressed, but the one being played should not look shut.
		mission_buttons[i].add_theme_color_override("font_disabled_color",
				UiStyle.BRASS_BRIGHT if i == index else Color(0.45, 0.46, 0.5))


## The words put together from parts, in the language of the moment.
func _word_missions() -> void:
	for i in mission_buttons.size():
		var entry: Dictionary = Missions.LIST[i]
		mission_buttons[i].text = "%d  %s" % [i + 1, "%s, %s" % [tr(entry["place"]), tr(entry["date"])]
				if entry["place"] != "" else tr(entry["name"])]
	language_button.text = Language.NAMES[Language.other()]
	difficulty_button.text = tr("Guards: %s") % tr(Difficulty.NAMES[Difficulty.level])
	var best := Campaign.best(Missions.id_at(_index))
	best_label.visible = best != null
	if best != null:
		best_label.text = tr("Best: %s, %s") % [tr(MissionScore.RATING_NAMES[best.rating()]), MissionScore.clock(best.seconds)]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and start_button != null:
		_word_missions()
		if _mission != null:
			_show_objectives(_mission.briefing_lines)


func _show_objectives(lines: Array) -> void:
	for child in _objective_box.get_children():
		_objective_box.remove_child(child)
		child.free()
	for line: String in lines:
		var label := _text("•  " + tr(line), 16, Color.WHITE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		_objective_box.add_child(label)


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
	UiStyle.label(label, size, color)
	label.add_theme_constant_override("outline_size", 0)
	return label
