class_name StoneDisplay
extends Node3D
## Shows every thrown stone: a pebble that flies in an arc from the thrower's hand to where it
## lands. It listens to each specialist's `acted` and never changes game state.

const FLIGHT_SECONDS := 0.45
const ARC_HEIGHT := 2.2
const HAND_HEIGHT := 1.5
const COLOR := Color(0.62, 0.60, 0.55)

## Stones in the air, oldest first.
var stones: Array[MeshInstance3D] = []

var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _age: Array[float] = []
var _hooked := {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group(Specialist.GROUP):
		_hook(node)


func _process(delta: float) -> void:
	for i in range(stones.size() - 1, -1, -1):
		_age[i] += delta
		var t := _age[i] / FLIGHT_SECONDS
		if t >= 1.0:
			stones[i].queue_free()
			stones.remove_at(i)
			_from.remove_at(i)
			_to.remove_at(i)
			_age.remove_at(i)
		else:
			stones[i].global_position = _from[i].lerp(_to[i], t) + Vector3.UP * ARC_HEIGHT * 4.0 * t * (1.0 - t)


func _on_node_added(node: Node) -> void:
	if node is Specialist:
		_hook(node)


func _hook(node: Node) -> void:
	var unit := node as Specialist
	if unit == null or _hooked.has(unit.get_instance_id()):
		return
	_hooked[unit.get_instance_id()] = true
	unit.acted.connect(_on_acted.bind(unit))


func _on_acted(what: StringName, at: Vector3, unit: Unit) -> void:
	if what != &"stone" or not is_instance_valid(unit):
		return
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.2
	ball.radial_segments = 6
	ball.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	ball.material = material
	var stone := MeshInstance3D.new()
	stone.mesh = ball
	add_child(stone)
	stone.global_position = unit.global_position + Vector3.UP * HAND_HEIGHT
	stones.append(stone)
	_from.append(stone.global_position)
	_to.append(at)
	_age.append(0.0)
