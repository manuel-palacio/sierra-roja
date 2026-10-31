class_name PerfProbe
extends Node
## Web-only frame rate probe for the performance check. Active only when the page URL
## has ?perf=1. Exposes window.sierraPerf() -> {fps, frames, guards, displacement}, averaged over the last 10 s.

const WINDOW_SECONDS := 10.0
const PUBLISH_INTERVAL := 0.5

var _stamps: PackedFloat64Array = PackedFloat64Array()
var _moves: PackedFloat64Array = PackedFloat64Array()  # guard distance moved, per frame
var _last_pos := {}
var _guards := 0
var _since_publish := 0.0


static func enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('perf')", true)) == "1"


func _ready() -> void:
	JavaScriptBridge.eval("window.sierraPerfData = {fps: 0, frames: 0, guards: 0, displacement: 0}; window.sierraPerf = () => window.sierraPerfData;", true)


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_stamps.append(now)
	_moves.append(_sample_guards())
	var cutoff := now - WINDOW_SECONDS
	var drop := 0
	while drop < _stamps.size() and _stamps[drop] < cutoff:
		drop += 1
	if drop > 0:
		_stamps = _stamps.slice(drop)
		_moves = _moves.slice(drop)
	_since_publish += delta
	if _since_publish >= PUBLISH_INTERVAL:
		_since_publish = 0.0
		_publish()


## Read-only: counts guards and returns how far they moved since the previous frame.
func _sample_guards() -> float:
	var guards := get_tree().get_nodes_in_group(Guard.GROUP)
	_guards = guards.size()
	var moved := 0.0
	for node in guards:
		var pos := (node as Node3D).global_position
		if _last_pos.has(node):
			moved += pos.distance_to(_last_pos[node])
		_last_pos[node] = pos
	return moved


func average_fps() -> float:
	if _stamps.size() < 2:
		return 0.0
	return (_stamps.size() - 1) / (_stamps[-1] - _stamps[0])


func _displacement() -> float:
	var total := 0.0
	for m in _moves:
		total += m
	return total


func _publish() -> void:
	JavaScriptBridge.eval("window.sierraPerfData = {fps: %f, frames: %d, guards: %d, displacement: %f};" % [average_fps(), _stamps.size(), _guards, _displacement()], true)
