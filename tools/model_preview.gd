extends SceneTree
## Design aid: renders a building made by the game's own code beside a model file, from the
## game's camera angle, to compare them.
##   godot --path . -s tools/model_preview.gd -- out.png res://assets/buildings/farmhouse.glb [view height in metres]
## Needs a window (no --headless): it reads the picture back from the renderer.


func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/model_preview_run.gd").new())
