extends RefCounted
## Plays the Carchuna mission through the orders a player has: Unit.move_to, set_stance and F at
## the cell door, with real guards, perception and physics. It reads guard positions and
## headings, which a player reads off the screen, and never touches guard state.
##
## The quiet way is on the belly the whole way. A figure lying down is seen only within six
## metres, and the route keeps farther than that from every beat: along the shore south of the
## path, in by the breach, along the foot of the south wall, and up the east side of the cells'
## court. The one thing to time is the sentry in the lane west of the cells. The Marksman waits
## by the launch.

## Game seconds.
const CAP := 420.0
const ARRIVE := 0.5

## Along the shore, south of the path, and up to the breach in the west wall.
const WAY_IN: Array[Vector3] = [Vector3(-34, 0, 27), Vector3(-20, 0, 27.5), Vector3(0, 0, 27.5), Vector3(5.5, 0, 22),
		Vector3(5.5, 0, 15.6), Vector3(9.6, 0, 15.6), Vector3(12.5, 0, 18.8), Vector3(30, 0, 18.9), Vector3(36, 0, 18.5)]
## East of the cells' door: more than six metres from the lane's south end.
const WAIT := Vector3(36, 0, 13)
## Where the launch lies, inside the extraction.
const LAUNCH := Vector3(-37.5, 0, 27.3)
const LAUNCH_M := Vector3(-38.5, 0, 26.2)
## Straight up the road and in at the gate, for the run that ignores stealth.
const GATE_WALK: Array[Vector3] = [Vector3(-20, 0, 0), Vector3(10, 0, -18), Vector3(23, 0, -14), Vector3(23, 0, -5)]

var mission: Mission
var rules: MissionRules
var dynamiter: Specialist
var marksman: Specialist
var prisoner: Prisoner
var door: CellDoor
var lane_guard: Guard

var elapsed := 0.0
## Guard name -> closest the Dynamiter or the prisoner came to it, in metres.
var closest: Dictionary = {}
var events: PackedStringArray = []
## Any guard left PATROL at any time.
var noticed := false
## The most guards in ALARM at once.
var max_alarm := 0

var _tree: SceneTree
var _states: Dictionary = {}


func _init(tree: SceneTree, m: Mission, r: MissionRules, specialists: Array[Specialist]) -> void:
	_tree = tree
	mission = m
	rules = r
	dynamiter = specialists[0]
	marksman = specialists[1]
	prisoner = m.prisoners()[0]
	door = m.get_node("CellDoor") as CellDoor
	lane_guard = m.guards()[4]
	for g in m.guards():
		closest[String(g.name)] = INF
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/carchuna.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
	await test.get_tree().physics_frame
	m.build_nav()
	var specialists := m.spawn_specialists()
	var r := MissionRules.new()
	test.add_child_autofree(r)
	r.setup(m, specialists)
	return (load("res://tests/run/carchuna_bot.gd") as GDScript).new(test.get_tree(), m, r, specialists)


func finish() -> void:
	if _tree.physics_frame.is_connected(_observe):
		_tree.physics_frame.disconnect(_observe)


func running() -> bool:
	return rules.result == MissionRules.Result.RUNNING and elapsed < CAP


func summary() -> String:
	return "t=%.1f result=%d noticed=%s max_alarm=%d door=%s closest=%s\n  %s" % [elapsed, rules.result, noticed,
			max_alarm, door.open, closest, "\n  ".join(events)]


func wait_until(cond: Callable) -> bool:
	while running():
		if cond.call():
			return true
		await _tree.physics_frame
	return false


func go(unit: Unit, pos: Vector3) -> bool:
	unit.move_to(_grounded(pos))
	return await wait_until(func() -> bool: return flat(unit.global_position, pos) <= ARRIVE)


## The full stealth play. Returns when the mission has ended or the cap ran out.
func play() -> void:
	_mark("down on their bellies")
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	marksman.set_stance(Unit.Stance.CRAWLING)
	marksman.move_to(_grounded(LAUNCH_M))
	for p in WAY_IN:
		if not await go(dynamiter, p):
			return
	await go(dynamiter, WAIT)
	_mark("wait for the lane sentry to go up the lane")
	# Walking north and already past the corner of the cells: the building hides the door from it
	# until it is back, and that is longer than the door and the way back out take.
	await wait_until(func() -> bool:
		return lane_guard.velocity.z < -0.5 and lane_guard.global_position.z < 9.5 and lane_guard.global_position.z > 6.0)
	await go(dynamiter, door.stand_point())
	_mark("the door")
	var thing := Interactable.nearest(_tree, dynamiter)
	if thing == null:
		_mark("nothing to use at the door")
		return
	thing.interact(dynamiter)
	await go(dynamiter, WAIT)
	_mark("out the way they came")
	await wait_until(func() -> bool: return flat(prisoner.global_position, dynamiter.global_position) < 3.5)
	var way_out := WAY_IN.duplicate()
	way_out.reverse()
	for p in way_out:
		if not await go(dynamiter, p):
			return
	await go(dynamiter, LAUNCH)
	_mark("at the launch")
	await wait_until(func() -> bool: return false)


## Upright up to the gate and in, with no regard for anyone.
func walk_in_by_the_gate() -> void:
	for p in GATE_WALK:
		if not await go(dynamiter, p):
			return


func _mark(stage: String) -> void:
	events.append("%.1f -- %s; D %s P %s lane %s" % [elapsed, stage, dynamiter.global_position.snappedf(0.1),
			prisoner.global_position.snappedf(0.1), lane_guard.global_position.snappedf(0.1)])


func _grounded(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z), p.z)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _observe() -> void:
	elapsed += _tree.root.get_physics_process_delta_time()
	max_alarm = maxi(max_alarm, rules.alarm_level)
	for g in mission.guards():
		if not g.alive:
			continue
		var key := String(g.name)
		closest[key] = minf(closest[key], flat(g.global_position, dynamiter.global_position))
		if prisoner.leader != null:
			closest[key] = minf(closest[key], flat(g.global_position, prisoner.global_position))
		if _states.get(g) != g.brain.state:
			_states[g] = g.brain.state
			noticed = noticed or g.brain.state != GuardBrain.State.PATROL
			events.append("%.1f %s %s at %s; D %s P %s" % [elapsed, key, GuardBrain.State.keys()[g.brain.state],
					g.global_position.snappedf(0.1), dynamiter.global_position.snappedf(0.1),
					prisoner.global_position.snappedf(0.1)])
