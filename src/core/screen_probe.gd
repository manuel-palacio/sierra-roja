class_name ScreenProbe
extends Node
## Web-only, read-only probe for the e2e screenshot test. Active only when the page URL has
## ?probe=1. window.sierraProbe() fills window.sierraGuards with the current screen position
## (canvas pixels) of each living guard, so a test can click one that is walking, and
## window.sierraState with the message on screen and the first specialist's ground position.


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
	var state := {}
	var main := get_parent()
	if main.hud != null:
		var label: Label = main.hud.message_label
		var pos: Vector3 = main.specialists[0].global_position
		state = { "message": label.text if label.visible else "", "pos": [pos.x, pos.z] }
	JavaScriptBridge.eval("window.sierraState = %s" % JSON.stringify(state), true)
