class_name CellDoor
extends Interactable
## A locked door a specialist opens from outside with F. Shut, its blocker (a solid under Nav/)
## stops sight and is cut out of the navmesh like a wall; opened, the blocker leaves the map and
## the navmesh is baked again, so the way in and out exists. It opens once and stays open.
## The door faces along its own +z: that is the side to stand on.

## The door has just been opened, by this specialist.
signal opened(user: Specialist)

## How far outside the door a specialist stands to open it.
const STAND_OFF := 1.2

## The solid in the doorway, from the mission.
@export var blocker: NodePath = NodePath("Nav/CellDoorBlock")

var open := false

var _block: Node3D
var _block_parent: Node


func _init() -> void:
	prompt = "The cell is open"


func _ready() -> void:
	super()
	_block = _mission().get_node_or_null(blocker) as Node3D if _mission() else null
	if _block != null:
		_block_parent = _block.get_parent()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_block) and not _block.is_inside_tree():
		_block.free()


func interact(user: Specialist) -> void:
	if open:
		return
	set_open(true)
	opened.emit(user)


## Opens or shuts the door without anyone at it, as a load does.
func set_open(value: bool) -> void:
	usable = not value
	if value == open:
		return
	open = value
	if _block != null:
		if open:
			_block_parent.remove_child(_block)
		else:
			_block_parent.add_child(_block)
	if _mission() != null:
		_mission().rebake_nav_soon()


## Sets the door on the ground. Mission calls this before the navmesh bake.
func settle(ground: Callable) -> void:
	global_position.y = ground.call(global_position.x, global_position.z)


## Where a specialist stands to open it: just outside, on the ground.
func stand_point() -> Vector3:
	var at := global_position + global_basis.z.normalized() * STAND_OFF
	var mission := _mission()
	if mission != null:
		at.y = mission.ground_height(at.x, at.z)
	return at


## Only from outside: the side the door faces.
func can_interact(user: Specialist) -> bool:
	return super(user) and (user.global_position - global_position).dot(global_basis.z) > 0.0


func _mission() -> Mission:
	var node := get_parent()
	while node != null and not node is Mission:
		node = node.get_parent()
	return node as Mission
