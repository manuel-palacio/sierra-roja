extends RefCounted
## Plays the Ebro mission through the orders a player has: Unit.move_to, set_stance and
## Ability.can_use/use, with real guards, perception and physics. It reads positions and
## headings, which a player reads off the screen, and never touches guard state.
##
## The quiet way is the knife, three times. The Dynamiter goes along the foot of the bank on his
## belly, more than six metres from the sentries' beats, which is as close as a figure lying down
## can be seen. At each post he waits until the sentry has turned west, crawls up past the end of
## the stack of crates beside the beat's east end and lies there; the stack hides him from the
## sentry coming back until the man is level with him, and by then he is at his shoulder. The
## beats end sixteen metres apart, so a body at the end of one is out of sight from the next and
## from the track. The Marksman lies where they landed until the bank is quiet.

## Game seconds: the mission's own clock is 300.
const CAP := 330.0
const ARRIVE := 0.5
## The foot of the bank.
const BANK_Z := -27.5
## Lying beside the east end of a beat: this far short of its end, and this far towards the river.
const AMBUSH_BACK := 0.3
const AMBUSH_OFF := 1.5
const LANDING := Vector3(3.2, 0, -27.3)
const LANDING_M := Vector3(5.2, 0, -27.8)

var mission: Mission
var rules: MissionRules
var dynamiter: Specialist
var marksman: Specialist
var silence: SilenceObjective
var sentries: Array[Guard] = []

var elapsed := 0.0
var events: PackedStringArray = []
var knifed := 0
## Game seconds at which the last sentry went down; INF until then.
var silenced_at := INF
## A guard reached ALARM while a sentry still stood.
var alarm_before_quiet := false
var shot_fired := false

var _tree: SceneTree
var _states: Dictionary = {}


func _init(tree: SceneTree, m: Mission, r: MissionRules, specialists: Array[Specialist]) -> void:
	_tree = tree
	mission = m
	rules = r
	dynamiter = specialists[0]
	marksman = specialists[1]
	silence = m.objectives()[0] as SilenceObjective
	for sentry in silence.sentries:
		sentries.append(m.get_node("Guards").get_node(NodePath(sentry)) as Guard)
	for g in m.guards():
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/ebro.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
	await test.get_tree().physics_frame
	m.build_nav()
	var specialists := m.spawn_specialists()
	var r := MissionRules.new()
	test.add_child_autofree(r)
	r.setup(m, specialists)
	return (load("res://tests/run/ebro_bot.gd") as GDScript).new(test.get_tree(), m, r, specialists)


func finish() -> void:
	if _tree.physics_frame.is_connected(_observe):
		_tree.physics_frame.disconnect(_observe)


func running() -> bool:
	return rules.result == MissionRules.Result.RUNNING and elapsed < CAP


func summary() -> String:
	return "t=%.1f result=%d knifed=%d silenced_at=%.1f alarm_before_quiet=%s reason=%s\n  %s" % [elapsed, rules.result,
			knifed, silenced_at, alarm_before_quiet, rules.loss_reason(), "\n  ".join(events)]


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
	for sentry in sentries:
		if not await _knife(sentry):
			return
	_mark("the bank is quiet: to the landing")
	dynamiter.set_stance(Unit.Stance.STANDING)
	marksman.set_stance(Unit.Stance.STANDING)
	_walk(marksman, [Vector3(-20, 0, BANK_Z), LANDING_M])
	await go(dynamiter, Vector3(dynamiter.global_position.x, 0, BANK_Z))
	await go(dynamiter, LANDING)
	await wait_until(func() -> bool: return false)


## One sentry: along the foot of the bank to below the east end of his beat, up beside the stack
## while his back is turned, and the knife as he comes level.
func _knife(sentry: Guard) -> bool:
	var beat := mission.guard_route(String(sentry.name))
	var east: Vector3 = beat[1] if beat[1].x > beat[0].x else beat[0]
	var ambush := Vector3(east.x - AMBUSH_BACK, 0, east.z - AMBUSH_OFF)
	var below := Vector3(east.x + 1.0, 0, BANK_Z)
	_mark("to below %s" % sentry.name)
	if not await go(dynamiter, Vector3(dynamiter.global_position.x, 0, BANK_Z)):
		return false
	if not await go(dynamiter, below):
		return false
	# His back turned and a good way off: time to crawl up and lie down before he is back.
	if not await wait_until(func() -> bool:
			return sentry.velocity.x < -1.0 and sentry.global_position.x < east.x - 6.0):
		return false
	if not await go(dynamiter, ambush):
		return false
	_mark("lying in wait for %s" % sentry.name)
	if not await wait_until(func() -> bool:
			return sentry.velocity.x > 1.0 and sentry.global_position.x > ambush.x - 0.6):
		return false
	var knife: Ability = dynamiter.abilities["knife"]
	dynamiter.set_stance(Unit.Stance.STANDING)
	while running() and is_instance_valid(sentry) and sentry.alive:
		if knife.can_use(dynamiter, sentry):
			knife.use(dynamiter, sentry)
			knifed += 1
			break
		dynamiter.move_to(sentry.global_position)
		await _tree.physics_frame
	dynamiter.stop()
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	_mark("a sentry is down")
	# A dead guard gives way to his body, so he may be gone altogether.
	return not is_instance_valid(sentry) or not sentry.alive


## The Marksman shoots the first sentry from where they landed: one down, and everyone awake.
func shoot_the_first_sentry() -> void:
	var rifle: Ability = marksman.abilities["rifle"]
	var sentry := sentries[0]
	if await wait_until(func() -> bool: return rifle.can_use(marksman, sentry)):
		rifle.use(marksman, sentry)
		shot_fired = true
		_mark("shot fired")
	await wait_until(func() -> bool: return false)


func _walk(unit: Unit, points: Array) -> void:
	for p in points:
		if not await go(unit, p):
			return


func _mark(stage: String) -> void:
	events.append("%.1f -- %s; D %s M %s left %d" % [elapsed, stage, dynamiter.global_position.snappedf(0.1),
			marksman.global_position.snappedf(0.1), silence.sentries_left()])


func _grounded(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z), p.z)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _observe() -> void:
	elapsed += _tree.root.get_physics_process_delta_time()
	if silence.done and silenced_at == INF:
		silenced_at = elapsed
	for g in mission.guards():
		if not g.alive:
			continue
		if _states.get(g) != g.brain.state:
			_states[g] = g.brain.state
			events.append("%.1f %s %s at %s; D %s M %s" % [elapsed, g.name, GuardBrain.State.keys()[g.brain.state],
					g.global_position.snappedf(0.1), dynamiter.global_position.snappedf(0.1),
					marksman.global_position.snappedf(0.1)])
		if g.brain.state == GuardBrain.State.ALARM and not silence.done:
			alarm_before_quiet = true
