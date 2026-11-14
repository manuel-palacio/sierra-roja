class_name UiStyle
extends RefCounted
## The look of the panels: dark field-green boxes with a brass edge, a typewriter face, and the
## pictures that go in them. One place, so the HUD, the briefing and the end screen match.

const FONT: FontFile = preload("res://assets/ui/SpecialElite-Regular.ttf")
const PANEL := Color(0.13, 0.14, 0.10, 0.90)
const PANEL_DEEP := Color(0.08, 0.09, 0.06, 0.94)
const BRASS := Color(0.66, 0.54, 0.28)
const BRASS_BRIGHT := Color(0.96, 0.82, 0.42)
const INK := Color(0.93, 0.89, 0.78)
const DIM := Color(0.62, 0.60, 0.52)
const PORTRAITS := {
	&"dynamiter": preload("res://assets/ui/portrait-dynamiter.png"),
	&"marksman": preload("res://assets/ui/portrait-marksman.png"),
}
const ICONS := {
	&"knife": preload("res://assets/ui/icon-knife.png"),
	&"charge": preload("res://assets/ui/icon-charge.png"),
	&"pistol": preload("res://assets/ui/icon-pistol.png"),
	&"rifle": preload("res://assets/ui/icon-rifle.png"),
	&"carry": preload("res://assets/ui/icon-carry.png"),
	&"stone": preload("res://assets/ui/icon-stone.png"),
}


## A framed box: `edge` wide in `edge_color`, the corners barely rounded.
static func box(fill := PANEL, edge_color := BRASS, edge := 2, padding := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge_color
	style.set_border_width_all(edge)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	return style


## Puts the typewriter face and the panel colours on a label.
static func label(target: Label, size: int, color := INK) -> Label:
	target.add_theme_font_override("font", FONT)
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)
	target.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	target.add_theme_constant_override("outline_size", 4)
	return target


## Dresses a button as a brass-edged plate that lights up under the pointer.
static func button(target: Button, size: int) -> Button:
	target.add_theme_font_override("font", FONT)
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", INK)
	target.add_theme_color_override("font_hover_color", BRASS_BRIGHT)
	target.add_theme_color_override("font_pressed_color", BRASS_BRIGHT)
	target.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	target.add_theme_stylebox_override("normal", box(PANEL, BRASS, 2, 6))
	target.add_theme_stylebox_override("hover", box(Color(0.20, 0.21, 0.15, 0.95), BRASS_BRIGHT, 2, 6))
	target.add_theme_stylebox_override("pressed", box(PANEL_DEEP, BRASS_BRIGHT, 2, 6))
	target.add_theme_stylebox_override("disabled", box(Color(0.10, 0.10, 0.09, 0.8), Color(BRASS, 0.35), 2, 6))
	target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return target
