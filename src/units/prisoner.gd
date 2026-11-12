class_name Prisoner
extends Unit
## Someone to bring out. Held, he stays where he is and no guard takes notice of him. Freed, he
## follows the specialist who freed him, does as they do (crawls when they crawl, runs when they
## run) and is hunted as they are. He cannot fight.

const GROUP := "prisoners"
## Where he stands behind the one he follows.
const FOLLOW_DISTANCE := 1.5
## Farther than this from them, he moves to catch up.
const CATCH_UP := 2.5

## A new order is given only once the place to make for has moved this far.
const REORDER := 0.75

## The specialist he follows; null while he is held.
var leader: Specialist
## Orders he has given himself to keep up, for tests: one a frame would be a fault.
var orders_given := 0

## Where he was last making for.
var _making_for := Vector3.INF


func _ready() -> void:
	super()
	add_to_group(GROUP)


func follow(s: Specialist) -> void:
	leader = s
	if s != null:
		add_to_group(HUNTED)
	elif is_in_group(HUNTED):
		remove_from_group(HUNTED)
		stop()


func _physics_process(delta: float) -> void:
	if alive and leader != null and is_instance_valid(leader) and leader.alive:
		if stance != leader.stance:
			set_stance(leader.stance)
		var away := leader.global_position - global_position
		away.y = 0.0
		if away.length() > CATCH_UP:
			_keep_up(leader.global_position - away.normalized() * FOLLOW_DISTANCE, leader.is_running())
	super(delta)


## Makes for a place behind the leader. He is not ordered afresh every frame: each order starts
## a new path, and for someone running each would be heard as a first footfall.
func _keep_up(place: Vector3, run: bool) -> void:
	var wants_run := run and can_run and stance == Stance.STANDING
	if _moving and wants_run == _running and place.distance_to(_making_for) < REORDER:
		return
	var heard_in := _noise_timer
	var was_running := _moving and _running
	_making_for = place
	orders_given += 1
	move_to(place, run)
	if was_running:
		_noise_timer = heard_in


func save_state() -> Dictionary:
	var d := super()
	d["leader"] = String(leader.name) if leader != null else ""
	return d
