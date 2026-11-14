class_name TitleScreen
extends CanvasLayer
## The first thing seen: the poster, the title, what the game is and its six missions, and Start. Start (or Enter, Space, or a tap on the
## button) takes it down, and the briefing is behind it. Continue, offered once a mission has
## been won, goes to the furthest mission that is open. It takes every key and click while it is
## up. Shown once in a session.

signal started()
## Continue was chosen: the index in Missions.LIST to go to.
signal continue_chosen(index: int)

const POSTER: Texture2D = preload("res://assets/ui/title.png")
const SUBTITLE := "Behind the lines, 1937–1943"
## What the game is, for someone who has never seen it.
const ABOUT: Array[String] = [
	"A game of stealth and tactics in the Spanish Civil War and after.",
	"You lead two Republican guerrillas, the Dynamiter and the Marksman, behind the lines: unseen where you can be, quick where you cannot.",
	"Six missions at real events. The places and dates are history's; the pair and their part in them are invented.",
]
const FOOT := "Mouse and keyboard, or fingers on a phone held sideways  ·  Credits and licences: /credits.txt"
const ABOUT_WIDTH := 400.0

static var seen := false

var title_label: Label
var start_button: Button
var continue_button: Button
## Switches to the other language, and is named for it in that language.
var language_button: Button
## One line for each mission of the campaign: its number, place and date.
var mission_labels: Array[Label] = []

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
	var about := PanelContainer.new()
	about.add_theme_stylebox_override("panel", UiStyle.box(Color(0.10, 0.08, 0.06, 0.84), UiStyle.BRASS, 2, 14))
	about.set_anchors_preset(Control.PRESET_CENTER_TOP)
	about.grow_horizontal = Control.GROW_DIRECTION_BOTH
	about.offset_top = 166
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(about)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 7)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	about.add_child(words)
	for line in ABOUT:
		var label := Label.new()
		label.text = line
		UiStyle.label(label, 14, UiStyle.INK)
		label.add_theme_constant_override("outline_size", 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(ABOUT_WIDTH, 0)
		words.add_child(label)
	words.add_child(HSeparator.new())
	for i in Missions.LIST.size():
		var label := Label.new()
		UiStyle.label(label, 13, UiStyle.BRASS_BRIGHT)
		label.add_theme_constant_override("outline_size", 0)
		words.add_child(label)
		mission_labels.append(label)
	var foot := Label.new()
	foot.text = FOOT
	UiStyle.label(foot, 12, Color(0.80, 0.76, 0.66))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_bottom = -12
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)
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
	language_button = UiStyle.button(Button.new(), 18)
	language_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_button.custom_minimum_size = Vector2(120, 48)
	language_button.pressed.connect(func() -> void: Language.choose(Language.other()))
	buttons.add_child(language_button)
	_word()


## The words put together from parts, in the language of the moment.
func _word() -> void:
	for i in mission_labels.size():
		var entry: Dictionary = Missions.LIST[i]
		mission_labels[i].text = "%d  %s, %s" % [i + 1, tr(entry["place"]), tr(entry["date"])]
	language_button.text = Language.NAMES[Language.other()]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and language_button != null:
		_word()


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
