class_name Hud
extends CanvasLayer
## Display only: two portraits with health and stance, the selected specialist's ability bar with
## ammo, the alarm level, the fuse of each planted charge, a pause indicator (with Restart) and
## short messages. It reads rules state and never writes it. The ability buttons, Restart and Keep
## playing are the only widgets that take the mouse; everything else ignores it so clicks and edge
## scrolling reach the game.

const OBJECTIVE_BRIDGE := "Objective: Destroy the bridge"
const OBJECTIVE_ESCAPE := "Objective: Reach the extraction point"
const MESSAGE_SECONDS := 3.0
const REFRESH_INTERVAL := 0.1

const LABELS := {
	&"knife": "Knife", &"pistol": "Pistol", &"rifle": "Rifle", &"charge": "Charge", &"carry": "Carry",
}
const KEYS := { &"knife": "Q", &"pistol": "R", &"rifle": "E", &"charge": "E", &"carry": "F" }

## Called by Restart. The default reloads the scene; tests replace it.
var restart_action := func() -> void: get_tree().reload_current_scene()

var root: Control
var top_bar: Control
var bottom_bar: Control
var alarm_label: Label
var message_label: Label
## What to do next; hidden once the mission has ended.
var objective_label: Label
## "Fuse: 3s, 9s", soonest first; hidden with no charge planted.
var fuse_label: Label
var pause_box: Control
var restart_button: Button
## Shown with a question in the message line after a bad save; answered with its two buttons.
var restart_offer: Control
var restart_offer_button: Button
var keep_playing_button: Button
var end_screen: EndScreen
## Specialist index -> bars.
var health_bars: Array[ProgressBar] = []
var stance_labels: Array[Label] = []
## Ability id (String) of the selected specialist -> Button.
var ability_buttons: Dictionary = {}

var _input: PlayerInput
var _rules: MissionRules
var _specialists: Array[Specialist] = []
var _overlay: VisionOverlay
var _portraits: Array[PanelContainer] = []
var _ability_row: HBoxContainer
var _bar_owner: Specialist
var _message_left := 0.0
var _since_refresh := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = _control(Control.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build_top()
	_build_bottom()
	_build_center()
	end_screen = EndScreen.new()
	end_screen.restart_pressed.connect(_restart)
	root.add_child(end_screen)
	_build_restart_offer()


func setup(input: PlayerInput, rules: MissionRules, specialists: Array[Specialist],
		overlay: VisionOverlay) -> void:
	_input = input
	_rules = rules
	_specialists = specialists
	_overlay = overlay
	_build_portraits()
	input.selection_changed.connect(func(_s: Specialist) -> void: refresh())
	input.paused_changed.connect(func(_p: bool) -> void: refresh())
	input.order_refused.connect(show_message)
	input.guard_clicked.connect(func(g: Guard) -> void: overlay.show_for(g))
	rules.result_changed.connect(func(r: MissionRules.Result) -> void: end_screen.show_result(r, rules.loss_reason()))
	rules.bridge_blown.connect(func() -> void: show_message("Bridge destroyed"))
	rules.charge_too_far.connect(func() -> void: show_message("The charge was too far from the bridge"))
	end_screen.show_result(rules.result, rules.loss_reason())
	refresh()


## Short text at the top of the screen for a few seconds.
func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_message_left = MESSAGE_SECONDS
	restart_offer.visible = false


## Keeps the current message up, as a question, until one of the two buttons answers it.
func offer_restart() -> void:
	restart_offer.visible = true
	_message_left = INF


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			message_label.visible = false
	_since_refresh += delta
	if _since_refresh >= REFRESH_INTERVAL:
		refresh()


## Reads the current state into the widgets.
func refresh() -> void:
	_since_refresh = 0.0
	if _input == null:
		return
	for i in _specialists.size():
		var s := _specialists[i]
		health_bars[i].max_value = s.stats.max_hp
		health_bars[i].value = s.hp
		stance_labels[i].visible = s.stance == Unit.Stance.CRAWLING
		_portraits[i].modulate = Color.WHITE if s in _input.selected_units() else Color(1, 1, 1, 0.6)
	_refresh_abilities()
	_refresh_fuse()
	alarm_label.text = "Alarm: %d" % _rules.alarm_level
	alarm_label.modulate = Color(1, 0.4, 0.3) if _rules.alarm_level > 0 else Color.WHITE
	objective_label.text = OBJECTIVE_ESCAPE if _rules.bridge_destroyed else OBJECTIVE_BRIDGE
	objective_label.visible = _rules.result == MissionRules.Result.RUNNING
	pause_box.visible = _input.is_paused()


func _refresh_abilities() -> void:
	var s := _input.selected
	if s != _bar_owner or ability_buttons.size() != (s.abilities.size() if s else 0):
		_bar_owner = s
		for child in _ability_row.get_children():
			child.queue_free()
		ability_buttons.clear()
		if s != null:
			for id in s.abilities:
				var button := Button.new()
				button.process_mode = Node.PROCESS_MODE_ALWAYS
				button.focus_mode = Control.FOCUS_NONE
				button.pressed.connect(func() -> void: _input.arm_ability(StringName(id)))
				_ability_row.add_child(button)
				ability_buttons[id] = button
	if _bar_owner == null:
		return
	for id in ability_buttons:
		var ability: Ability = _bar_owner.abilities[id]
		var button: Button = ability_buttons[id]
		var text := "%s %s" % [KEYS.get(StringName(id), "?"), LABELS.get(StringName(id), id)]
		if ability.ammo >= 0:
			text += " x%d" % ability.ammo
		button.text = text
		button.disabled = ability.ammo == 0
		button.modulate = Color(1, 0.9, 0.4) if _input.armed_ability == StringName(id) else Color.WHITE


func _refresh_fuse() -> void:
	var left: Array[float] = []
	for node in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		if not node.is_queued_for_deletion():
			left.append((node as PlantedCharge).fuse_left)
	left.sort()
	var parts := PackedStringArray()
	for seconds in left:
		parts.append("%ds" % ceili(seconds))
	fuse_label.visible = not left.is_empty()
	fuse_label.text = "Fuse: " + ", ".join(parts)


func _restart() -> void:
	# Reloading rebuilds all rules state; only the engine pause has to be cleared by hand.
	get_tree().paused = false
	restart_action.call()


func _build_restart_offer() -> void:
	restart_offer = _control(HBoxContainer.new())
	restart_offer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	restart_offer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	restart_offer.offset_top = 48
	restart_offer.add_theme_constant_override("separation", 12)
	restart_offer.visible = false
	root.add_child(restart_offer)
	restart_offer_button = _offer_button("Restart")
	restart_offer_button.pressed.connect(func() -> void:
		_close_offer()
		_restart())
	keep_playing_button = _offer_button("Keep playing")
	keep_playing_button.pressed.connect(_close_offer)


func _offer_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.focus_mode = Control.FOCUS_NONE
	restart_offer.add_child(button)
	return button


func _close_offer() -> void:
	restart_offer.visible = false
	message_label.visible = false
	_message_left = 0.0


func _build_top() -> void:
	top_bar = _control(MarginContainer.new())
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		top_bar.add_theme_constant_override("margin_" + side, 12)
	root.add_child(top_bar)
	var row := _control(HBoxContainer.new())
	row.add_theme_constant_override("separation", 16)
	top_bar.add_child(row)
	alarm_label = _label("Alarm: 0")
	row.add_child(alarm_label)
	objective_label = _label("")
	objective_label.modulate = Color(0.8, 0.92, 1.0)
	row.add_child(objective_label)
	fuse_label = _label("")
	fuse_label.modulate = Color(1, 0.65, 0.3)
	fuse_label.visible = false
	row.add_child(fuse_label)
	message_label = _label("")
	message_label.visible = false
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(message_label)


func _build_bottom() -> void:
	bottom_bar = _control(MarginContainer.new())
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right", "bottom"]:
		bottom_bar.add_theme_constant_override("margin_" + side, 12)
	root.add_child(bottom_bar)
	var row := _control(HBoxContainer.new())
	row.add_theme_constant_override("separation", 16)
	bottom_bar.add_child(row)
	_ability_row = _control(HBoxContainer.new())
	_ability_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_row.alignment = BoxContainer.ALIGNMENT_END
	_ability_row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_ability_row)


func _build_portraits() -> void:
	var row := bottom_bar.get_child(0) as HBoxContainer
	for i in _specialists.size():
		var s := _specialists[i]
		var panel := _control(PanelContainer.new()) as PanelContainer
		var box := _control(VBoxContainer.new())
		panel.add_child(box)
		box.add_child(_label("%d  %s" % [i + 1, "Dynamiter" if s.has_ability("charge") else "Marksman"]))
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(140, 14)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("fill", _flat(Color(0.3, 0.8, 0.35)))
		bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.1, 0.1, 0.8)))
		box.add_child(bar)
		var stance := _label("Crawling")
		stance.visible = false
		box.add_child(stance)
		stance_labels.append(stance)
		row.add_child(panel)
		row.move_child(panel, i)
		_portraits.append(panel)
		health_bars.append(bar)


func _build_center() -> void:
	pause_box = _control(CenterContainer.new())
	pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.visible = false
	pause_box.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_box)
	var box := _control(VBoxContainer.new())
	pause_box.add_child(box)
	var paused := _label("Paused")
	paused.add_theme_font_size_override("font_size", 40)
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(paused)
	box.add_child(_label("Space to resume"))
	(box.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(_restart)
	box.add_child(restart_button)


static func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box


static func _control(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
