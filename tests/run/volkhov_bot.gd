extends RefCounted
## Plays the Volkhov mission through the orders a player has: Unit.move_to, set_stance and F at
## the table, with real guards, perception and physics. It reads only what a player sees.
##
## The quiet way is on the belly: over the drifted ice in the south, round the back of the hamlet
## and up to the command post from the south-east, in at the door, the orders off the table, and
## out the same way. A figure lying down is seen only within six metres, and the route keeps
## farther than that from every beat. Back on the west bank the wood is theirs and they walk.
## The Marksman goes straight to the dug-out.

## Game seconds.
const CAP := 420.0
const ARRIVE := 0.5

## Through the wood to the drifts, over the ice, and round behind the hamlet to the door.
const WAY_IN: Array[Vector3] = [Vector3(-30, 0, 34), Vector3(-12, 0, 33), Vector3(10, 0, 32), Vector3(20, 0, 32),
		Vector3(35.5, 0, 31), Vector3(35.5, 0, 8), Vector3(28.5, 0, 3), Vector3(30, 0, -1.8), Vector3(30.2, 0, -4.6)]
## Beside the table in the north-west corner.
const TABLE := Vector3(28.0, 0, -7.3)
## Back in the wood, where they get up and walk.
const WOOD := Vector3(-12, 0, 33)
const WAY_HOME: Array[Vector3] = [Vector3(-30, 0, 22), Vector3(-44, 0, 0), Vector3(-43.2, 0, -29)]
const MARKSMAN_HOME: Array[Vector3] = [Vector3(-46, 0, 0), Vector3(-45.2, 0, -30.5)]
## Upright straight over the ice in front of the machine-gun post, for the run that ignores stealth.
const OPEN_ICE: Array[Vector3] = [Vector3(-14, 0, 0), Vector3(14, 0, 0), Vector3(28, 0, 2)]

var mission: Mission
var rules: MissionRules
var dynamiter: Specialist
var marksman: Specialist
var item: Carryable

var elapsed := 0.0
## Guard name -> closest the Dynamiter came to it, in metres.
var closest: Dictionary = {}
var events: PackedStringArray = []
## Any guard left PATROL at any time.
var noticed := false
## The most guards in ALARM at once.
var max_alarm := 0
var orders_taken := false

var _tree: SceneTree
var _states: Dictionary = {}


func _init(tree: SceneTree, m: Mission, r: MissionRules, specialists: Array[Specialist]) -> void:
	_tree = tree
	mission = m
	rules = r
	dynamiter = specialists[0]
	marksman = specialists[1]
	item = (m.objectives()[0] as StealObjective).item_node()
	for g in m.guards():
		closest[String(g.name)] = INF
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/volkhov.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
	await test.get_tree().physics_frame
	m.build_nav()
	var specialists := m.spawn_specialists()
	var r := MissionRules.new()
	test.add_child_autofree(r)
	r.setup(m, specialists)
	return (load("res://tests/run/volkhov_bot.gd") as GDScript).new(test.get_tree(), m, r, specialists)


func finish() -> void:
	if _tree.physics_frame.is_connected(_observe):
		_tree.physics_frame.disconnect(_observe)


func running() -> bool:
	return rules.result == MissionRules.Result.RUNNING and elapsed < CAP


func summary() -> String:
	return "t=%.1f result=%d noticed=%s max_alarm=%d orders=%s closest=%s\n  %s" % [elapsed, rules.result, noticed,
			max_alarm, orders_taken, closest, "\n  ".join(events)]


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
	_mark("the Marksman to the dug-out, the Dynamiter down on his belly")
	_walk(marksman, MARKSMAN_HOME)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	for p in WAY_IN:
		if not await go(dynamiter, p):
			return
	await go(dynamiter, TABLE)
	_mark("at the table")
	var thing := Interactable.nearest(_tree, dynamiter)
	if thing == null:
		_mark("nothing to take at the table")
		return
	thing.interact(dynamiter)
	orders_taken = item.carrier == dynamiter
	_mark("out the way he came")
	var way_out := WAY_IN.duplicate()
	way_out.reverse()
	for p in way_out:
		if not await go(dynamiter, p):
			return
	await go(dynamiter, WOOD)
	_mark("in the wood: up and walking")
	dynamiter.set_stance(Unit.Stance.STANDING)
	for p in WAY_HOME:
		if not await go(dynamiter, p):
			return
	_mark("at the dug-out")
	await wait_until(func() -> bool: return false)


## Upright straight over the open ice, with no regard for anyone.
func walk_over_the_open_ice() -> void:
	_walk(dynamiter, OPEN_ICE)


func _walk(unit: Unit, points: Array) -> void:
	for p in points:
		if not await go(unit, p):
			return


func _mark(stage: String) -> void:
	events.append("%.1f -- %s; D %s M %s" % [elapsed, stage, dynamiter.global_position.snappedf(0.1),
			marksman.global_position.snappedf(0.1)])


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
		if _states.get(g) != g.brain.state:
			_states[g] = g.brain.state
			noticed = noticed or g.brain.state != GuardBrain.State.PATROL
			events.append("%.1f %s %s at %s; D %s M %s" % [elapsed, key, GuardBrain.State.keys()[g.brain.state],
					g.global_position.snappedf(0.1), dynamiter.global_position.snappedf(0.1),
					marksman.global_position.snappedf(0.1)])
