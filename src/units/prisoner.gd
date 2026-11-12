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

## The specialist he follows; null while he is held.
var leader: Specialist


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
			move_to(leader.global_position - away.normalized() * FOLLOW_DISTANCE, leader.is_running())
	super(delta)


func save_state() -> Dictionary:
	var d := super()
	d["leader"] = String(leader.name) if leader != null else ""
	return d
