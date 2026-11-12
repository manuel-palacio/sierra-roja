class_name PlantedCharge
extends Node3D
## A charge on its fuse. At zero it kills every unit within the blast radius, specialists and
## anyone with them included, with no line-of-sight check, and makes a very loud noise. Bodies in the blast are
## not touched, so they stay discoverable.

signal detonated(pos: Vector3)

const GROUP := "charges"

var tuning: AbilityTuning
var fuse_left := 10.0
var _done := false


func _ready() -> void:
	if tuning == null:
		tuning = AbilityTuning.defaults()
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	advance(delta)


## Tests call this directly to run the fuse with no waiting.
func advance(delta: float) -> void:
	if _done:
		return
	fuse_left -= delta
	if fuse_left <= 0.0:
		_detonate()


func save_state() -> Dictionary:
	return { "fuse_left": fuse_left, "pos": [global_position.x, global_position.y, global_position.z] }


func load_state(d: Dictionary) -> void:
	fuse_left = float(d["fuse_left"])
	var p: Array = d["pos"]
	global_position = Vector3(p[0], p[1], p[2])


func _detonate() -> void:
	_done = true
	fuse_left = 0.0
	var pos := global_position
	NoiseBus.emit_noise(pos, tuning.blast_noise_radius)
	var victims: Array = []
	victims.append_array(get_tree().get_nodes_in_group(Guard.GROUP))
	victims.append_array(get_tree().get_nodes_in_group(Unit.HUNTED))
	for node in victims:
		var unit := node as Unit
		if unit != null and unit.global_position.distance_to(pos) <= tuning.blast_radius:
			unit.take_damage(tuning.blast_damage)
	detonated.emit(pos)
	queue_free()
