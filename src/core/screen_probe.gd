class_name ScreenProbe
extends Node
## Web-only, read-only probe for the e2e screenshot test. Active only when the page URL has
## ?probe=1. window.sierraProbe() fills window.sierraGuards with the current screen position
## (canvas pixels) of each living guard, so a test can click one that is walking.


static func enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('probe')", true)) == "1"


var _callback: JavaScriptObject


func _ready() -> void:
	_callback = JavaScriptBridge.create_callback(_publish)
	JavaScriptBridge.get_interface("window").sierraProbe = _callback


func _publish(_args: Array) -> void:
	var cam := get_viewport().get_camera_3d()
	var points: Array = []
	for node in get_tree().get_nodes_in_group(Guard.GROUP):
		var guard := node as Guard
		if guard.alive and cam != null:
			var p := cam.unproject_position(guard.global_position + Vector3.UP * 0.85)
			points.append([p.x, p.y])
	JavaScriptBridge.eval("window.sierraGuards = %s" % JSON.stringify(points), true)
