class_name Carryable
extends Interactable
## Something to take away: papers on a table. F next to it takes it up; it then rides with the
## specialist who has it until they put it down (F again) or fall, and lies where that happens.
## Whoever has it can still crawl and fight, but has no hands for a body.

## A specialist has just taken it up.
signal taken(by: Specialist)
## It has just been put down, or dropped, here.
signal put_down(at: Vector3)

## What the player is told it is.
@export var label := "Orders"

## Who has it; null while it lies somewhere.
var carrier: Specialist

var _look: MeshInstance3D
var _on_back: MeshInstance3D


func _ready() -> void:
	super()
	# A bundle of papers in an oilcloth: small, pale, and easy to pick out on a table.
	_look = MeshInstance3D.new()
	_look.mesh = _bundle()
	_look.position = Vector3(0, 0.03, 0)
	add_child(_look)


func can_interact(user: Specialist) -> bool:
	return carrier == null and super(user) and user.holding == null and user.carrying == null


func interact(user: Specialist) -> void:
	if not can_interact(user):
		return
	give_to(user)
	taken.emit(user)


## Puts it in a specialist's hands with nothing said, as a load does. Whoever had it loses it.
func give_to(user: Specialist) -> void:
	if carrier != null:
		_leave(carrier)
	carrier = user
	user.holding = self
	usable = false
	visible = false
	if not user.died.is_connected(_on_carrier_died):
		user.died.connect(_on_carrier_died)
	_on_back = MeshInstance3D.new()
	_on_back.name = "Held"
	_on_back.mesh = _bundle()
	_on_back.position = Vector3(0.0, 1.05, -0.24)
	user.add_child(_on_back)


## Lies down at the carrier's feet and can be taken up again.
func drop() -> void:
	if carrier == null:
		return
	var at := carrier.global_position
	lie_at(at)
	put_down.emit(at)


## Lies at a place in nobody's hands, with nothing said, as a load does.
func lie_at(at: Vector3) -> void:
	if carrier != null:
		_leave(carrier)
	carrier = null
	global_position = at
	usable = true
	visible = true


func _leave(user: Specialist) -> void:
	if is_instance_valid(user):
		if user.holding == self:
			user.holding = null
		if user.died.is_connected(_on_carrier_died):
			user.died.disconnect(_on_carrier_died)
	if is_instance_valid(_on_back):
		_on_back.queue_free()
	_on_back = null


func _on_carrier_died(_unit: Unit) -> void:
	drop()


static func _bundle() -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.07, 0.24)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.86, 0.80, 0.62)
	cloth.roughness = 1.0
	mesh.material = cloth
	return mesh
