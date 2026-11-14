class_name Touch
extends RefCounted
## Whether the game is being played with fingers: on a phone or a tablet (a browser whose main
## pointer is coarse, or ?touch=1 in the address), or anywhere from the first touch on. The HUD
## then shows buttons for what the keyboard does, and the briefing tells of taps, not keys.

static var _active := false
static var _asked := false


static func active() -> bool:
	if not _asked:
		_asked = true
		if OS.has_feature("web"):
			_active = bool(JavaScriptBridge.eval(
					"new URLSearchParams(location.search).get('touch') === '1'"
					+ " || (window.matchMedia && window.matchMedia('(pointer: coarse)').matches)", true))
	return _active


static func set_active(value: bool) -> void:
	_asked = true
	_active = value
