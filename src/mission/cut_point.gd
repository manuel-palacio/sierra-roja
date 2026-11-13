class_name CutPoint
extends Interactable
## A place on a telephone line that can be cut: F next to it, then a few seconds standing still.
## Moving off, being ordered to move, or falling stops the work, and it starts from nothing next
## time. It makes no noise and can be done lying down. Once cut it stays cut.

## The line has just been cut here.
signal was_cut()

## Seconds of standing still it takes.
const CUT_SECONDS := 4.0

## The TelegraphPole whose wires come down, from the mission. May be empty.
@export var pole: NodePath

var cut := false
## Seconds of cutting done so far.
var progress := 0.0
## Who is at it; null when nobody is.
var cutter: Specialist


func _init() -> void:
	prompt = "Cutting the line: stand still"


func _ready() -> void:
	super()
	# The junction box the line runs through, at chest height on the pole: the place to look for.
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.32, 0.14)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.72, 0.16, 0.12)
	paint.roughness = 1.0
	box.material = paint
	var look := MeshInstance3D.new()
	look.mesh = box
	look.position = Vector3(0, 1.3, 0.16)
	add_child(look)


## Sets the place on the ground. Mission calls this before the navmesh bake.
func settle(ground: Callable) -> void:
	global_position.y = ground.call(global_position.x, global_position.z)


func can_interact(user: Specialist) -> bool:
	return not cut and cutter == null and super(user)


func interact(user: Specialist) -> void:
	if not can_interact(user):
		return
	# F at the pole halts him there: the work is done standing still.
	user.stop()
	cutter = user
	progress = 0.0


func _physics_process(delta: float) -> void:
	if cutter == null:
		return
	if not is_instance_valid(cutter) or not cutter.alive or cutter.is_moving() or not _in_reach(cutter):
		cutter = null
		progress = 0.0
		return
	progress += delta
	if progress >= CUT_SECONDS:
		set_cut(true)
		was_cut.emit()


## Cut or whole, with nobody at it, as a load leaves it.
func set_cut(value: bool) -> void:
	cut = value
	usable = not value
	cutter = null
	progress = 0.0
	var mission := _mission()
	var post := mission.get_node_or_null(pole) as TelegraphPole if mission != null and not pole.is_empty() else null
	if post != null:
		if value:
			post.drop_wire()
		else:
			post.raise_wire()


func _in_reach(user: Specialist) -> bool:
	return Vector2(user.global_position.x - global_position.x, user.global_position.z - global_position.z).length() <= reach


func _mission() -> Mission:
	var node := get_parent()
	while node != null and not node is Mission:
		node = node.get_parent()
	return node as Mission
