extends RefCounted
## Plays the bridge mission through the orders a player has: Unit.move_to, set_stance and
## Ability.can_use/use, with real guards, perception and physics. It reads positions and headings,
## which a player reads off the screen and the vision overlay, and never touches guard state.
##
## Every wait polls on the physics frame and gives up when the mission ends or the cap runs out,
## so a run that goes wrong fails its assertions instead of hanging.

## Game seconds.
const CAP := 300.0
## Close enough to a waypoint; a unit stops within 0.3 m of it.
const ARRIVE := 0.5

# The stealth play goes round by the west footpath and the north side, where no turning guard
# ever looks (guards swing round through the south at each end of an east-west beat).

## South of the west footpath, out of the track guard's sight even when it faces this way.
const WAIT_WEST := Vector3(-53.5, 0.0, 12.5)
const WAIT_WEST_M := Vector3(-52.0, 0.0, 13.5)
## Over the railway by the footpath, then away from it: beyond 13 m to the side, a walker on the
## track never has anyone both inside its cone and inside its range.
const CROSS_TOP := Vector3(-49.5, 0.0, 0.0)
const NORTH_FOOT := Vector3(-53.5, 0.0, -9.5)
const NORTH_PLAIN := Vector3(-50.0, 0.0, -14.5)
const NORTH_MID := Vector3(-33.0, 0.0, -15.0)
## Lying here they are in the sentry's far zone at worst, which a crawler passes.
const RAMP_FOOT := Vector3(-20.0, 0.0, -10.5)
const RAMP_FOOT_M := Vector3(-21.5, 0.0, -12.0)
const RAMP_TOP := Vector3(-12.0, 0.0, -1.9)
## Just west of the crate beside the rails: it hides someone lying here from a guard coming west.
const AMBUSH := Vector3(-11.0, 0.0, -1.9)
const WEST_ABUTMENT := Vector3(-7.0, 0.0, 0.0)
## 3.5 m from the bridge target, well inside the 8 m the charge needs.
const PLANT_ON_DECK := Vector3(3.5, 0.0, 0.0)
const MARKSMAN_ON_DECK := Vector3(6.5, 0.0, 0.0)
## Along the track and down the east footpath: 30 m and more from the charge when it goes.
const EAST_TRACK := Vector3(37.5, 0.0, 0.0)
const EAST_FOOT := Vector3(44.5, 0.0, 10.0)
const PAD_A := Vector3(46.5, 0.0, 28.5)
const PAD_B := Vector3(45.0, 0.0, 27.0)
## The road through the checkpoint and along the track, for the run that ignores stealth.
const ROUTE: Array[Vector3] = [Vector3(-30, 0, 34), Vector3(-30, 0, 12), Vector3(-30, 0, 0), WEST_ABUTMENT,
		PLANT_ON_DECK]

## Runs the game four times faster with the same simulation: more physics ticks per wall second, so
## each tick still covers 1/60 of a game second. Restore with release, even after a failure.
class FastClock:
	const SPEED := 4
	var _time_scale := 1.0
	var _ticks := 60
	var _max_steps := 8

	func engage() -> void:
		_time_scale = Engine.time_scale
		_ticks = Engine.physics_ticks_per_second
		_max_steps = Engine.max_physics_steps_per_frame
		Engine.time_scale = SPEED
		Engine.physics_ticks_per_second = _ticks * SPEED
		Engine.max_physics_steps_per_frame = _max_steps * SPEED

	func release() -> void:
		Engine.time_scale = _time_scale
		Engine.physics_ticks_per_second = _ticks
		Engine.max_physics_steps_per_frame = _max_steps


var mission: Mission
var rules: MissionRules
var dynamiter: Specialist
var marksman: Specialist
var track_guard: Guard
var sentry: Guard

var elapsed := 0.0
## Guard name -> closest either specialist came to it, in metres.
var closest: Dictionary = {}
## Guard state changes with where everyone stood.
var events: PackedStringArray = []
var alarm_seen := false
## Any guard left PATROL at all before the charge went off (suspicion counts).
var noticed_before_blast := false
var knife_used := false
var body_hidden := false

var _tree: SceneTree
var _states: Dictionary = {}


func _init(tree: SceneTree, m: Mission, r: MissionRules, specialists: Array[Specialist]) -> void:
	_tree = tree
	mission = m
	rules = r
	dynamiter = specialists[0]
	marksman = specialists[1]
	var guards := m.guards()
	track_guard = guards[2]
	sentry = guards[3]
	for g in guards:
		closest[String(g.name)] = INF
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
	await test.get_tree().physics_frame
	m.build_nav()
	var specialists := m.spawn_specialists()
	var r := MissionRules.new()
	test.add_child_autofree(r)
	r.setup(m, specialists)
	return (load("res://tests/run/bridge_bot.gd") as GDScript).new(test.get_tree(), m, r, specialists)


## Disconnects the bookkeeping; call when the run is over.
func finish() -> void:
	if _tree.physics_frame.is_connected(_observe):
		_tree.physics_frame.disconnect(_observe)


func running() -> bool:
	return rules.result == MissionRules.Result.RUNNING and elapsed < CAP


func summary() -> String:
	return "t=%.1f result=%d alarm=%s noticed=%s knife=%s hidden=%s closest=%s\n  %s" % [elapsed, rules.result,
			alarm_seen, noticed_before_blast, knife_used, body_hidden, closest, "\n  ".join(events)]


## Waits until cond is true. False when the mission ended or the cap ran out first.
func wait_until(cond: Callable) -> bool:
	while running():
		if cond.call():
			return true
		await _tree.physics_frame
	return false


## Orders the move and waits for it. The unit keeps whatever stance it has.
func go(unit: Specialist, pos: Vector3) -> bool:
	unit.move_to(_grounded(pos))
	return await wait_until(func() -> bool: return flat(unit.global_position, pos) <= ARRIVE)


func at(unit: Specialist, pos: Vector3) -> bool:
	return flat(unit.global_position, pos) <= ARRIVE


## The full stealth play. Returns when the mission has ended or the cap ran out.
func play() -> void:
	await _cross_the_railway()
	await _reach_the_ramp()
	await _lie_in_wait()
	await _knife_the_sentry()
	await _hide_the_body()
	await _onto_the_deck()
	await _plant_and_leave()
	await wait_until(func() -> bool: return false)


## Both wait south of the footpath until the track guard has turned east, then walk over the
## railway behind its back and on to the north plain. It needs 23 m of walking; the guard gives
## its back for 16 m of its own and is out of range for 3 m more.
func _cross_the_railway() -> void:
	_mark("cross the railway")
	marksman.move_to(_grounded(WAIT_WEST_M))
	await go(dynamiter, WAIT_WEST)
	await wait_until(func() -> bool: return at(marksman, WAIT_WEST_M))
	await wait_until(func() -> bool:
		return track_guard.velocity.x > 0.0 and track_guard.global_position.x > -42.0 \
				and track_guard.global_position.x < -39.0)
	_walk_route(marksman, [CROSS_TOP, NORTH_FOOT, NORTH_PLAIN])
	await _walk_route(dynamiter, [CROSS_TOP, NORTH_FOOT, NORTH_PLAIN])
	await wait_until(func() -> bool: return at(marksman, NORTH_PLAIN))


## East along the hillside, well back from the track, then down on their bellies near the ramp.
func _reach_the_ramp() -> void:
	_mark("reach the ramp")
	_walk_route(marksman, [NORTH_MID, RAMP_FOOT_M])
	await _walk_route(dynamiter, [NORTH_MID, RAMP_FOOT])
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	await wait_until(func() -> bool: return at(marksman, RAMP_FOOT_M))
	marksman.set_stance(Unit.Stance.CRAWLING)


## Up the ramp behind the sentry's back as it starts east, and flat behind the crate before it
## turns. 11 m of walking against the 32 m it walks before it is back. The foot of the ramp can
## be seen from the last metre and a half of the track guard's beat, so that guard must be going
## away, or still far from its east end.
func _lie_in_wait() -> void:
	_mark("lie in wait")
	await wait_until(func() -> bool:
		var x := sentry.global_position.x
		var track_clear := track_guard.velocity.x < 0.0 or track_guard.global_position.x < -39.0
		return sentry.velocity.x > 0.0 and x > -11.0 and x < -8.0 and track_clear)
	dynamiter.set_stance(Unit.Stance.STANDING)
	await _walk_route(dynamiter, [RAMP_TOP, AMBUSH])
	dynamiter.set_stance(Unit.Stance.CRAWLING)


## The sentry comes west past the crate; as it draws level the Dynamiter is at its shoulder.
func _knife_the_sentry() -> void:
	_mark("knife the sentry")
	var knife: Ability = dynamiter.abilities["knife"]
	await wait_until(func() -> bool:
		return sentry.velocity.x < 0.0 and sentry.global_position.x < AMBUSH.x + 0.6)
	dynamiter.set_stance(Unit.Stance.STANDING)
	while running() and sentry.alive:
		if knife.can_use(dynamiter, sentry):
			knife.use(dynamiter, sentry)
			knife_used = true
			break
		dynamiter.move_to(sentry.global_position)
		await _tree.physics_frame
	dynamiter.stop()


## The body goes behind the crate, off the rails.
func _hide_the_body() -> void:
	_mark("hide the body")
	if not knife_used:
		return
	await _tree.physics_frame
	var bodies := _tree.get_nodes_in_group(Body.GROUP)
	var carry: Ability = dynamiter.abilities["carry"]
	if not bodies.is_empty() and carry.can_use(dynamiter, bodies[0]):
		carry.use(dynamiter, bodies[0])
		await go(dynamiter, AMBUSH)
		carry.use(dynamiter, null)
		body_hidden = true


## With the sentry gone the bridge is clear: the Marksman comes up and both walk out onto it.
func _onto_the_deck() -> void:
	_mark("onto the deck")
	marksman.set_stance(Unit.Stance.STANDING)
	_walk_route(marksman, [RAMP_TOP, WEST_ABUTMENT, MARKSMAN_ON_DECK])
	await _walk_route(dynamiter, [WEST_ABUTMENT, PLANT_ON_DECK])
	await wait_until(func() -> bool: return at(marksman, MARKSMAN_ON_DECK))


## The 10 s fuse covers 30 m of walking, well clear of the 8 m blast.
func _plant_and_leave() -> void:
	_mark("plant and leave")
	var charge: Ability = dynamiter.abilities["charge"]
	if not running() or not charge.can_use(dynamiter, null):
		return
	charge.use(dynamiter, null)
	_walk_route(marksman, [EAST_TRACK, EAST_FOOT, PAD_B])
	await _walk_route(dynamiter, [EAST_TRACK, EAST_FOOT, PAD_A])


## Both walk the road upright with no regard for the guards, the Dynamiter leading.
func walk_upright() -> void:
	_walk_route(marksman, ROUTE)
	await _walk_route(dynamiter, ROUTE)


## Notes the start of a stage of the play among the events, for reading a failed run.
func _mark(stage: String) -> void:
	events.append("%.1f -- %s; D %s M %s" % [elapsed, stage, dynamiter.global_position.snappedf(0.1),
			marksman.global_position.snappedf(0.1)])


func _walk_route(unit: Specialist, points: Array) -> void:
	for p in points:
		if not await go(unit, p):
			return


## The same point of the ground plane, at the height of the land there.
func _grounded(p: Vector3) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.z) if absf(p.x) > Mission.BANK_EDGE_X else 0.0, p.z)


static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _observe() -> void:
	elapsed += _tree.root.get_physics_process_delta_time()
	for g in mission.guards():
		if not g.alive:
			continue
		var key := String(g.name)
		for s: Specialist in [dynamiter, marksman]:
			closest[key] = minf(closest[key], flat(g.global_position, s.global_position))
		if _states.get(g) != g.brain.state:
			_states[g] = g.brain.state
			events.append("%.1f %s %s at %s; D %s M %s" % [elapsed, key, GuardBrain.State.keys()[g.brain.state],
					g.global_position.snappedf(0.1), dynamiter.global_position.snappedf(0.1),
					marksman.global_position.snappedf(0.1)])
		if g.brain.state == GuardBrain.State.ALARM:
			alarm_seen = true
		if g.brain.state != GuardBrain.State.PATROL and not rules.bridge_destroyed:
			noticed_before_blast = true
