extends RefCounted
## Plays the Krasny Bor mission through the orders a player has: Unit.move_to, set_stance, F at
## the poles and the charge, with real guards, perception and physics. It reads only what a
## player sees.
##
## The quiet way is on the belly: out of the wood by the west, north past the end of the gun line
## and the dug-out, east along behind the telephone poles cutting each as it comes, down the east
## side to the foot of the store's wall, the charge, and away into the open country to the
## south-east before it goes. A figure lying down is seen only within six metres, and the route
## keeps farther than that from every beat. What the blast brings is fair, as at the bridge.
## The Marksman goes through the wood to the hollow.

## Game seconds.
const CAP := 480.0
const ARRIVE := 0.5

## Round by the west to behind the line of poles.
const WAY_ROUND: Array[Vector3] = [Vector3(-40, 0, 20), Vector3(-40, 0, 0), Vector3(-40, 0, -26.5)]
## Behind the poles, this far north of the line.
const BEHIND_Z := -26.5
## Where to lie to cut: north of the pole, in reach of it.
const AT_POLE := Vector3(0.6, 0, -1.2)
## Down the east side to the foot of the store's east wall.
const WAY_DOWN: Array[Vector3] = [Vector3(50, 0, -26.5), Vector3(50, 0, -2), Vector3(46, 0, 2), Vector3(40.6, 0, 2)]
## More than the blast's eight metres from the charge, towards the wood.
const CLEAR_OF_IT := Vector3(47, 0, 13)
const WAY_HOME: Array[Vector3] = [Vector3(46, 0, 26), Vector3(44.5, 0, 34.5)]
const MARKSMAN_HOME: Array[Vector3] = [Vector3(-20, 0, 39), Vector3(10, 0, 40), Vector3(42.5, 0, 36)]
## Upright straight at the guns, for the run that ignores stealth.
const AT_THE_GUNS: Array[Vector3] = [Vector3(-20, 0, 24), Vector3(-6, 0, 10), Vector3(-6, 0, 0)]

var mission: Mission
var rules: MissionRules
var dynamiter: Specialist
var marksman: Specialist
var cut: CutObjective
var destroy: DestroyObjective

var elapsed := 0.0
## Guard name -> closest the Dynamiter came to it before the blast, in metres.
var closest: Dictionary = {}
var events: PackedStringArray = []
var lines_cut := 0
var charge_planted := false
## Any guard left PATROL before the store went up.
var noticed_before_blast := false
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
	cut = m.objectives()[0] as CutObjective
	destroy = m.objectives()[1] as DestroyObjective
	for g in m.guards():
		closest[String(g.name)] = INF
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/krasny_bor.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
	await test.get_tree().physics_frame
	m.build_nav()
	var specialists := m.spawn_specialists()
	var r := MissionRules.new()
	test.add_child_autofree(r)
	r.setup(m, specialists)
	return (load("res://tests/run/krasny_bor_bot.gd") as GDScript).new(test.get_tree(), m, r, specialists)


func finish() -> void:
	if _tree.physics_frame.is_connected(_observe):
		_tree.physics_frame.disconnect(_observe)


func running() -> bool:
	return rules.result == MissionRules.Result.RUNNING and elapsed < CAP


func summary() -> String:
	return "t=%.1f result=%d lines=%d planted=%s noticed_before_blast=%s max_alarm=%d reason=%s closest=%s\n  %s" % [
			elapsed, rules.result, lines_cut, charge_planted, noticed_before_blast, max_alarm, rules.loss_reason(),
			closest, "\n  ".join(events)]


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
	_mark("the Marksman through the wood, the Dynamiter down on his belly")
	_walk(marksman, MARKSMAN_HOME)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	for p in WAY_ROUND:
		if not await go(dynamiter, p):
			return
	for point in cut.point_nodes():
		if not await _cut(point):
			return
	_mark("the lines are cut: to the store")
	for p in WAY_DOWN:
		if not await go(dynamiter, p):
			return
	var charge: Ability = dynamiter.abilities["charge"]
	if not charge.can_use(dynamiter, null):
		_mark("no charge to plant")
		return
	charge.use(dynamiter, null)
	charge_planted = true
	_mark("the charge is laid")
	if not await go(dynamiter, CLEAR_OF_IT):
		return
	await wait_until(func() -> bool: return destroy.done)
	_mark("the store is up: home")
	for p in WAY_HOME:
		if not await go(dynamiter, p):
			return
	await wait_until(func() -> bool: return false)


## Along behind the poles to this one, F, and four seconds without moving.
func _cut(point: CutPoint) -> bool:
	var stand := point.global_position + AT_POLE
	if not await go(dynamiter, Vector3(stand.x, 0, BEHIND_Z)):
		return false
	if not await go(dynamiter, stand):
		return false
	dynamiter.stop()
	var thing := Interactable.nearest(_tree, dynamiter)
	if thing != point:
		_mark("nothing to cut at %s" % point.name)
		return false
	thing.interact(dynamiter)
	if not await wait_until(func() -> bool: return point.cut):
		return false
	lines_cut += 1
	_mark("%s is cut" % point.name)
	return await go(dynamiter, Vector3(stand.x, 0, BEHIND_Z))


## Upright straight at the guns, with no regard for anyone.
func walk_up_to_the_guns() -> void:
	_walk(dynamiter, AT_THE_GUNS)


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
		if not destroy.done:
			closest[key] = minf(closest[key], flat(g.global_position, dynamiter.global_position))
		if _states.get(g) != g.brain.state:
			_states[g] = g.brain.state
			events.append("%.1f %s %s at %s; D %s M %s" % [elapsed, key, GuardBrain.State.keys()[g.brain.state],
					g.global_position.snappedf(0.1), dynamiter.global_position.snappedf(0.1),
					marksman.global_position.snappedf(0.1)])
		if g.brain.state != GuardBrain.State.PATROL and not destroy.done:
			noticed_before_blast = true
