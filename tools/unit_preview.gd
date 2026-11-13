extends SceneTree
## Design aid: renders unit scenes side by side to a PNG, close up, from the game's camera angle.
##   godot --path . -s tools/unit_preview.gd -- out.png [animation] [seconds into it] [yaw degrees] [view height in metres] [height looked at] [pitch] [dress]
## Needs a window (no --headless): it reads the picture back from the renderer.


func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/unit_preview_run.gd").new())
