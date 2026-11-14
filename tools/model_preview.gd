extends SceneTree
## Design aid: renders a building made of plain shapes beside the same building drawn from its
## Blender model (see tools/make_buildings.py), from the game's camera angle.
##   godot --path . -s tools/model_preview.gd -- out.png [length height depth roof storeys snowy view]
## Needs a window (no --headless): it reads the picture back from the renderer.


func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/model_preview_run.gd").new())
