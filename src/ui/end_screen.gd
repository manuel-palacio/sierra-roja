class_name EndScreen
extends Control
## "Mission complete" or "Mission failed" with a Restart button. Display only; the restart
## itself is whatever the HUD hands it.

signal restart_pressed()
signal next_pressed()

var title_label: Label
## Why, under a failure.
var reason_label: Label
var restart_button: Button
## Shown after a win when there is another mission to go on to.
var next_button: Button
var offer_next := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	title_label = Label.new()
	UiStyle.label(title_label, 48, UiStyle.BRASS_BRIGHT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	reason_label = Label.new()
	UiStyle.label(reason_label, 20)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.visible = false
	box.add_child(reason_label)
	restart_button = UiStyle.button(Button.new(), 20)
	restart_button.text = "Restart"
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_button)
	next_button = UiStyle.button(Button.new(), 20)
	next_button.text = "Next mission"
	next_button.process_mode = Node.PROCESS_MODE_ALWAYS
	next_button.visible = false
	next_button.pressed.connect(func() -> void: next_pressed.emit())
	box.add_child(next_button)


func show_result(result: MissionRules.Result, reason := "") -> void:
	reason_label.text = reason
	reason_label.visible = reason != ""
	next_button.visible = offer_next and result == MissionRules.Result.WON
	match result:
		MissionRules.Result.WON:
			title_label.text = "Mission complete"
		MissionRules.Result.LOST:
			title_label.text = "Mission failed"
		_:
			visible = false
			return
	visible = true
