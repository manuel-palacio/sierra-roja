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

# The stealth play is the gorge path: across the road south of the checkpoint, up along the rim
# of the gorge, and onto the railway by the footpath at the west abutment. Guards turn right
# about clockwise, so the sentry on the bridge sweeps the north side at the west end of its beat
# and never the south, where the path comes up.

## West of the road, 17 m from the road guard's southern turn: out of its range even standing.
const ROAD_FAR := Vector3(-46.5, 0.0, 38.5)
## Closer in, lying down: inside its far zone, which a crawler passes, and beyond the near one.
const ROAD_NEAR := Vector3(-37.5, 0.0, 38.5)
const ROAD_NEAR_M := Vector3(-38.6, 0.0, 39.2)
## Across, and out of the cone it looks south with.
const ROAD_EAST := Vector3(-20.0, 0.0, 38.0)
## North along the rim, east of the field wall.
const RIM_SOUTH := Vector3(-10.5, 0.0, 30.0)
const RIM_NORTH := Vector3(-10.5, 0.0, 13.5)
## The foot of the footpath. From here to the track the checkpoint guard can see a standing
## figure for the first few metres, so they lie here until it looks elsewhere.
const RAMP_FOOT := Vector3(-13.8, 0.0, 8.5)
const RAMP_FOOT_M := Vector3(-15.0, 0.0, 9.8)
const RAMP_TOP := Vector3(-7.3, 0.0, 2.2)
## Round the crate by the rails to its west side.
const TRACK_EAST_OF_CRATE := Vector3(-7.3, 0.0, -0.1)
const TRACK_WEST_OF_CRATE := Vector3(-11.6, 0.0, -0.1)
## Just west of the crate beside the rails: it hides someone lying here from a guard coming west.
const AMBUSH := Vector3(-11.7, 0.0, 1.5)
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
var checkpoint_guard: Guard
var road_guard: Guard
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
	checkpoint_guard = guards[0]
	road_guard = guards[1]
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
	await _cross_the_road()
	await _reach_the_ramp()
	await _lie_in_wait()
	await _knife_the_sentry()
	await _hide_the_body()
	await _onto_the_deck()
	await _plant_and_leave()
	await wait_until(func() -> bool: return false)


## Both crawl up to the road south of the road guard's beat and lie there. When it has turned and
## set off north they get up and walk across behind its back, and are out of its cone again
## before it has come back down.
func _cross_the_road() -> void:
	_mark("cross the road")
	marksman.move_to(_grounded(ROAD_FAR + Vector3(0, 0, 0.9)))
	await go(dynamiter, ROAD_FAR)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	marksman.set_stance(Unit.Stance.CRAWLING)
	marksman.move_to(_grounded(ROAD_NEAR_M))
	await go(dynamiter, ROAD_NEAR)
	await wait_until(func() -> bool: return at(marksman, ROAD_NEAR_M))
	await wait_until(func() -> bool:
		var z := road_guard.global_position.z
		return road_guard.velocity.z < -1.0 and z < 29.0 and z > 26.5)
	dynamiter.set_stance(Unit.Stance.STANDING)
	marksman.set_stance(Unit.Stance.STANDING)
	_walk_route(marksman, [ROAD_EAST + Vector3(-1.5, 0, 0.8), RIM_SOUTH + Vector3(0, 0, 1.5)])
	await _walk_route(dynamiter, [ROAD_EAST, RIM_SOUTH])


## North along the rim of the gorge, then on their bellies for the last stretch to the foot of
## the footpath, which the checkpoint guard looks toward from the far end of its round.
func _reach_the_ramp() -> void:
	_mark("reach the ramp")
	_walk_route(marksman, [RIM_NORTH + Vector3(0, 0, 1.5)])
	await go(dynamiter, RIM_NORTH)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	await wait_until(func() -> bool: return at(marksman, RIM_NORTH + Vector3(0, 0, 1.5)))
	marksman.set_stance(Unit.Stance.CRAWLING)
	marksman.move_to(_grounded(RAMP_FOOT_M))
	await go(dynamiter, RAMP_FOOT)
	await wait_until(func() -> bool: return at(marksman, RAMP_FOOT_M))


## Up the footpath behind the sentry's back as it sets off east, round the crate and flat behind
## it before the sentry is back. 16 m of walking against the 32 m and two look-rounds the sentry
## has ahead of it. The checkpoint guard must be looking elsewhere for the first few metres.
func _lie_in_wait() -> void:
	_mark("lie in wait")
	await wait_until(func() -> bool:
		var x := sentry.global_position.x
		return sentry.velocity.x > 1.0 and x > -10.5 and x < -7.5 and _checkpoint_looks_away())
	dynamiter.set_stance(Unit.Stance.STANDING)
	await _walk_route(dynamiter, [RAMP_TOP, TRACK_EAST_OF_CRATE, TRACK_WEST_OF_CRATE, AMBUSH])
	dynamiter.set_stance(Unit.Stance.CRAWLING)


## The sentry comes west past the crate; as it draws level the Dynamiter is at its shoulder.
func _knife_the_sentry() -> void:
	_mark("knife the sentry")
	var knife: Ability = dynamiter.abilities["knife"]
	await wait_until(func() -> bool:
		return sentry.velocity.x < -1.0 and sentry.global_position.x < AMBUSH.x + 0.6)
	dynamiter.set_stance(Unit.Stance.STANDING)
	while running() and sentry.alive:
		if knife.can_use(dynamiter, sentry):
			knife.use(dynamiter, sentry)
			knife_used = true
			break
		dynamiter.move_to(sentry.global_position)
		await _tree.physics_frame
	dynamiter.stop()


## The checkpoint guard is on the part of its round from which it will not look east along the
## foot of the embankment for the next couple of seconds.
func _checkpoint_looks_away() -> bool:
	var facing := -checkpoint_guard.global_basis.z
	return checkpoint_guard.global_position.z > 12.5 and facing.x < 0.5


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


## With the sentry gone the bridge is clear: the Marksman comes up when the checkpoint guard is
## looking elsewhere, and both walk out onto it.
func _onto_the_deck() -> void:
	_mark("onto the deck")
	await wait_until(_checkpoint_looks_away)
	marksman.set_stance(Unit.Stance.STANDING)
	_walk_route(marksman, [RAMP_TOP, WEST_ABUTMENT, MARKSMAN_ON_DECK])
	dynamiter.set_stance(Unit.Stance.STANDING)
	await _walk_route(dynamiter, [TRACK_WEST_OF_CRATE, WEST_ABUTMENT, PLANT_ON_DECK])
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
		if g.brain.state != GuardBrain.State.PATROL and not rules.objectives_done():
			noticed_before_blast = true
