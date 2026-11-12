extends SceneTree
## Renders a head-and-shoulders picture of each specialist for the HUD's portraits.
##   godot --path . -s tools/portrait_render.gd -- /tmp/portraits
## Needs a window (no --headless). tools/make_ui_art.py then crops and finishes them.


func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/portrait_render_run.gd").new())
