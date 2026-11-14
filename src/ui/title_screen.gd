class_name TitleScreen
extends CanvasLayer
## The first thing seen: the poster, the title, and Start. Start (or Enter, Space, or a tap on the
## button) takes it down, and the briefing is behind it. Continue, offered once a mission has
## been won, goes to the furthest mission that is open. It takes every key and click while it is
## up. Shown once in a session.

signal started()
## Continue was chosen: the index in Missions.LIST to go to.
signal continue_chosen(index: int)

const POSTER: Texture2D = preload("res://assets/ui/title.png")
const SUBTITLE := "Behind the lines, 1937–1943"

static var seen := false

var title_label: Label
var start_button: Button
var continue_button: Button

var _done := false


## Where a person is the one starting the game, once: not in test runs, nor with the browser
## probes or ?briefing=1, which go straight to what they test.
static func wanted() -> bool:
	if seen or DisplayServer.get_name() == "headless" or PerfProbe.enabled() or ScreenProbe.enabled():
		return false
	if OS.has_feature("web") and str(JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('briefing')", true)) == "1":
		return false
	return true


## The furthest mission the campaign has opened.
static func furthest_open() -> int:
	var index := 0
	while Campaign.is_open(index + 1):
		index += 1
	return index


func _init() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back := ColorRect.new()
	back.color = Color(0.118, 0.098, 0.071)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks stop here
	add_child(back)
	var poster := TextureRect.new()
	poster.texture = POSTER
	poster.set_anchors_preset(Control.PRESET_FULL_RECT)
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(poster)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_WIDE)
	column.offset_top = 22
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title_label = Label.new()
	title_label.text = Briefing.TITLE
	UiStyle.label(title_label, 92, Color(0.72, 0.13, 0.08))
	title_label.add_theme_color_override("font_outline_color", Color(0.118, 0.098, 0.071))
	title_label.add_theme_constant_override("outline_size", 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	var subtitle := Label.new()
	subtitle.text = SUBTITLE
	UiStyle.label(subtitle, 24, Color(0.118, 0.098, 0.071))
	subtitle.add_theme_constant_override("outline_size", 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	buttons.offset_bottom = -64
	buttons.add_theme_constant_override("separation", 16)
	add_child(buttons)
	start_button = UiStyle.button(Button.new(), 24)
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(200, 48)
	start_button.pressed.connect(begin)
	buttons.add_child(start_button)
	continue_button = UiStyle.button(Button.new(), 24)
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(200, 48)
	continue_button.visible = furthest_open() > Missions.current
	continue_button.pressed.connect(func() -> void:
		if not _done:
			_done = true
			seen = true
			continue_chosen.emit(furthest_open()))
	buttons.add_child(continue_button)


func _input(event: InputEvent) -> void:
	if _done or not event is InputEventKey:
		return
	var key := event as InputEventKey
	# Every key stops here: none reaches the briefing or the game behind.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	if key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		begin()


## Takes the title down and says so, once.
func begin() -> void:
	if _done:
		return
	_done = true
	seen = true
	visible = false
	started.emit()
	queue_free()
