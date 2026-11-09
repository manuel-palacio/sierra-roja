extends SceneTree
## Design aid: writes a top-down picture of a mission after its navmesh bake.
##   godot --headless --path . -s tools/map_preview.gd -- out.png [res://path/to/mission.tscn]
## The work is in map_preview_run.gd, loaded here once the autoloads exist (a script given to -s
## is compiled before them, so it cannot name anything that uses one).


func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/map_preview_run.gd").new())
