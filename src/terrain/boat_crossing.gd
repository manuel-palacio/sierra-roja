class_name BoatCrossing
extends Node3D
## Launches that set out over the water when an objective is met, and come in to the bank.
## Display only: they stop nothing and nobody, and nothing waits on them.

## The Objective whose completion starts them, from the mission.
@export var after: NodePath
## How long the crossing takes.
@export var seconds := 25.0
## Where each boat lies before, and where it comes in (x, z), pair by pair.
@export var starts := PackedVector2Array()
@export var ends := PackedVector2Array()
## The height of the water they ride on.
@export var level := 0.0

var crossing := false

var _boats: Array[Node3D] = []
var _gone := 0.0
var _objective: Objective


func _ready() -> void:
	for i in mini(starts.size(), ends.size()):
		var boat := _boat()
		add_child(boat)
		_boats.append(boat)
	_place()
	var mission := _mission()
	if mission == null:
		return
	_objective = mission.get_node_or_null(after) as Objective
	if _objective != null:
		_objective.completed.connect(start)
	mission.state_loaded.connect(_on_loaded)


## Sets them going. Safe to call again.
func start() -> void:
	crossing = true


## Puts them at the far bank at once, as a load made after they crossed finds them.
func arrive() -> void:
	crossing = true
	_gone = seconds
	_place()


## Back where they wait, as a load from before finds them.
func wait() -> void:
	crossing = false
	_gone = 0.0
	_place()


## How far over they are: 0 waiting, 1 come in.
func progress() -> float:
	return clampf(_gone / maxf(seconds, 0.001), 0.0, 1.0)


func boats() -> Array[Node3D]:
	return _boats


func _process(delta: float) -> void:
	if crossing and _gone < seconds:
		_gone = minf(_gone + delta, seconds)
		_place()


func _place() -> void:
	var t := progress()
	for i in _boats.size():
		var at := starts[i].lerp(ends[i], t)
		_boats[i].position = Vector3(at.x, level, at.y)
		var heading := ends[i] - starts[i]
		if heading.length() > 0.01:
			_boats[i].rotation.y = atan2(heading.x, heading.y)


func _on_loaded() -> void:
	if _objective != null and _objective.done:
		arrive()
	else:
		wait()


func _mission() -> Mission:
	var node := get_parent()
	while node != null and not node is Mission:
		node = node.get_parent()
	return node as Mission


## An open boat full of men: a hull, and dark shapes sitting low in it.
static func _boat() -> Node3D:
	var boat := Node3D.new()
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.6, 5.0)
	box.material = Surfaces.material(&"planks", Color(0.45, 0.42, 0.36))
	hull.mesh = box
	hull.position = Vector3(0, 0.2, 0)
	boat.add_child(hull)
	var men := MeshInstance3D.new()
	var load_of_men := BoxMesh.new()
	load_of_men.size = Vector3(1.3, 0.5, 3.8)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.20, 0.21, 0.18)
	dark.roughness = 1.0
	load_of_men.material = dark
	men.mesh = load_of_men
	men.position = Vector3(0, 0.7, -0.2)
	boat.add_child(men)
	return boat
