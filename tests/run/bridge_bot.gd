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
## The north side of the crate beside the bank guard's route, hidden from the guard as it walks north.
const BEHIND_CRATE := Vector3(-23.4, 0.0, 3.4)
const SOUTH_GAP_WEST := Vector3(-28.0, 0.0, 9.5)
## Just out of the bridge guard's sight for a crawler, and where the two wait for their moment.
const WEST_OF_LOOP := Vector3(-21.5, 0.0, 2.5)
const MARKSMAN_WEST_OF_LOOP := Vector3(-23.0, 0.0, 8.0)
## 6 m or more from both the bridge guard's east leg and the east guard's west leg, so a crawler is safe.
const PLANT_ON_DECK := Vector3(0.0, 0.0, 0.0)
const MARKSMAN_ON_DECK := Vector3(-1.5, 0.0, 0.0)
## South-east leg to extraction, around the east guard's loop.
const EAST_BANK_SOUTH := Vector3(6.0, 0.0, 12.0)
const EAST_BANK_FAR := Vector3(26.0, 0.0, 13.0)
const PAD_A := Vector3(36.0, 0.0, 19.0)
const PAD_B := Vector3(34.0, 0.0, 17.0)
## The winning route's waypoints, in order, for the run that ignores stealth.
const ROUTE: Array[Vector3] = [SOUTH_GAP_WEST, BEHIND_CRATE, WEST_OF_LOOP, PLANT_ON_DECK,
		EAST_BANK_SOUTH, EAST_BANK_FAR, PAD_A]

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
var bridge_guard: Guard
var bank_guard: Guard
var east_guard: Guard

var elapsed := 0.0
## Guard name -> closest either specialist came to it, in metres.
var closest: Dictionary = {}
## Guard state changes with where everyone stood.
var events: PackedStringArray = []
var alarm_seen := false
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
	bridge_guard = guards[0]
	bank_guard = guards[1]
	east_guard = guards[2]
	for g in guards:
		closest[String(g.name)] = INF
		_states[g] = g.brain.state
	_tree.physics_frame.connect(_observe)


## Loads the mission into the test as the game does and hands back a bot for it.
static func start(test: GutTest) -> RefCounted:
	var m: Mission = load("res://scenes/missions/bridge.tscn").instantiate()
	test.add_child_autofree(m)
	await test.get_tree().process_frame
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
	return "t=%.1f result=%d alarm=%s knife=%s hidden=%s closest=%s\n  %s" % [elapsed, rules.result,
			alarm_seen, knife_used, body_hidden, closest, "\n  ".join(events)]


## Waits until cond is true. False when the mission ended or the cap ran out first.
func wait_until(cond: Callable) -> bool:
	while running():
		if cond.call():
			return true
		await _tree.physics_frame
	return false


## Orders the move and waits for it. The unit keeps whatever stance it has.
func go(unit: Specialist, pos: Vector3) -> bool:
	unit.move_to(pos)
	return await wait_until(func() -> bool: return flat(unit.global_position, pos) <= ARRIVE)


## The full stealth play. Returns when the mission has ended or the cap ran out.
func play() -> void:
	await _reach_the_crate()
	await _knife_the_bank_guard()
	await _hide_the_body()
	await _cross_to_the_deck()
	await _plant_and_leave()
	await wait_until(func() -> bool: return false)


## Slips through the south gap just as the bank guard's back comes round, and is lying behind the
## crate before the guard has turned at the south end of its route. The crate nearly touches the
## wall, so the way there is along the guard's side of it, 1 m off the route.
func _reach_the_crate() -> void:
	await go(dynamiter, SOUTH_GAP_WEST)
	await wait_until(func() -> bool:
		var z := bank_guard.global_position.z
		return bank_guard.velocity.z > 0.0 and z > 4.5 and z < 9.0 and _bridge_guard_away_at_the_knife())
	dynamiter.move_to(BEHIND_CRATE)
	await wait_until(func() -> bool:
		return bank_guard.global_position.z > 15.0 \
				or flat(dynamiter.global_position, BEHIND_CRATE) <= ARRIVE)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	await wait_until(func() -> bool: return flat(dynamiter.global_position, BEHIND_CRATE) <= ARRIVE)


## Waits for the bank guard to come level with the crate, then steps out behind its shoulder.
func _knife_the_bank_guard() -> void:
	var knife: Ability = dynamiter.abilities["knife"]
	await wait_until(func() -> bool:
		return bank_guard.velocity.z < 0.0 and bank_guard.global_position.z < BEHIND_CRATE.z + 1.0)
	dynamiter.set_stance(Unit.Stance.STANDING)
	while running() and bank_guard.alive:
		if knife.can_use(dynamiter, bank_guard):
			knife.use(dynamiter, bank_guard)
			knife_used = true
			break
		dynamiter.move_to(bank_guard.global_position)
		await _tree.physics_frame
	dynamiter.stop()


## Carries the body behind the crate, then both wait lying down on the west side of the bridge
## guard's loop.
func _hide_the_body() -> void:
	if not knife_used:
		return
	await _tree.physics_frame
	var bodies := _tree.get_nodes_in_group(Body.GROUP)
	var carry: Ability = dynamiter.abilities["carry"]
	if not bodies.is_empty() and carry.can_use(dynamiter, bodies[0]):
		carry.use(dynamiter, bodies[0])
		await go(dynamiter, BEHIND_CRATE)
		carry.use(dynamiter, null)
		body_hidden = true


## West of the loop they are safe from the bridge guard only lying down, so they crawl the last
## stretch. They stand and walk once it is on its east leg heading north: it will not look their
## way for about 6 s.
func _cross_to_the_deck() -> void:
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	dynamiter.move_to(WEST_OF_LOOP)
	await go(marksman, SOUTH_GAP_WEST)
	marksman.set_stance(Unit.Stance.CRAWLING)
	marksman.move_to(MARKSMAN_WEST_OF_LOOP)
	await wait_until(func() -> bool:
		return flat(marksman.global_position, MARKSMAN_WEST_OF_LOOP) <= ARRIVE \
				and flat(dynamiter.global_position, WEST_OF_LOOP) <= ARRIVE)
	await wait_until(_bridge_guard_leaving_the_mouth)
	dynamiter.set_stance(Unit.Stance.STANDING)
	marksman.set_stance(Unit.Stance.STANDING)
	marksman.move_to(MARKSMAN_ON_DECK)
	await go(dynamiter, PLANT_ON_DECK)
	dynamiter.set_stance(Unit.Stance.CRAWLING)
	await wait_until(func() -> bool:
		return flat(marksman.global_position, MARKSMAN_ON_DECK) <= ARRIVE)
	marksman.set_stance(Unit.Stance.CRAWLING)


## Plants as the east guard turns away along its south leg, then both go round behind it. The
## 10 s fuse covers 30 m of walking, well clear of the 8 m blast.
func _plant_and_leave() -> void:
	await wait_until(func() -> bool:
		return _east_guard_turned_away() and not _bridge_guard_looking_east())
	var charge: Ability = dynamiter.abilities["charge"]
	if not running() or not charge.can_use(dynamiter, null):
		return
	charge.use(dynamiter, null)
	dynamiter.set_stance(Unit.Stance.STANDING)
	marksman.set_stance(Unit.Stance.STANDING)
	_walk_route(marksman, [EAST_BANK_SOUTH, EAST_BANK_FAR, PAD_B])
	await _walk_route(dynamiter, [EAST_BANK_SOUTH, EAST_BANK_FAR, PAD_A])


## Both walk the winning route upright with no regard for the guards, the Dynamiter leading.
func walk_upright() -> void:
	_walk_route(marksman, ROUTE)
	await _walk_route(dynamiter, ROUTE)


func _walk_route(unit: Specialist, points: Array) -> void:
	for p in points:
		if not await go(unit, p):
			return


## Starting its east leg, walking north: the ground to the west stays behind it until it has come
## round to its west leg, and that takes the Marksman's whole walk from the crate to the deck.
func _bridge_guard_leaving_the_mouth() -> bool:
	var p := bridge_guard.global_position
	return bridge_guard.velocity.z < 0.0 and p.x > -9.0 and p.z > 4.0 and p.z < 5.5


## Whether it will look along the deck within the next 6 s, which is how long the walk off the
## bridge takes. North leg, then west leg, then the first stretch of the south leg is all clear.
func _bridge_guard_looking_east() -> bool:
	var p := bridge_guard.global_position
	var heading_north := bridge_guard.velocity.z < 0.0
	var heading_west := bridge_guard.velocity.x < 0.0
	var early_south_leg := p.x < -13.0 and p.z < -3.0
	return not (heading_north or heading_west or early_south_leg)


## The knife means standing, 12 m from its west leg, 6 to 8 s from now. That must not fall in the
## first stretch of the west leg, where it looks towards the crate, so it must not be on its south
## leg or the start of its east leg now.
func _bridge_guard_away_at_the_knife() -> bool:
	var p := bridge_guard.global_position
	return not (p.z > 0.0 and p.x > -13.5)


## Just round the corner onto its south leg, walking east: next it goes north up its far leg.
func _east_guard_turned_away() -> bool:
	var p := east_guard.global_position
	return east_guard.velocity.x > 0.0 and p.z > 7.0 and p.x > 12.5 and p.x < 17.0


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
