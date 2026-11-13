extends GutTest
## The bridge mission's map: valid, on real ground, with three ways to the bridge.

const SCENE := "res://scenes/missions/bridge.tscn"
## Waypoints of each route from the start to the west end of the bridge.
const ROAD_ROUTE: Array[Vector2] = [Vector2(-30, 34), Vector2(-30, 12), Vector2(-30, 0), Vector2(-7, 0)]
const GORGE_ROUTE: Array[Vector2] = [Vector2(-30, 36), Vector2(-11, 30), Vector2(-13, 9), Vector2(-7, 1.5)]
const HILL_ROUTE: Array[Vector2] = [Vector2(-53, 8), Vector2(-49, 0), Vector2(-53, -8), Vector2(-40, -16),
		Vector2(-31, -20.5), Vector2(-19.5, -9), Vector2(-11, -1.5)]

var mission: Mission


func _load(guards_active := false) -> void:
	mission = load(SCENE).instantiate()
	if not guards_active:
		mission.get_node("Guards").process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(mission)
	await get_tree().process_frame
	await get_tree().physics_frame


func _built(guards_active := false) -> void:
	await _load(guards_active)
	mission.build_nav()
	await wait_physics_frames(2)


func _on_ground(p: Vector2) -> Vector3:
	return Vector3(p.x, mission.ground_height(p.x, p.y), p.y)


func _path_length(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(mission.nav_map(), from, to, true)
	if path.is_empty() or Vector2(path[-1].x - to.x, path[-1].z - to.z).length() > 1.0:
		return INF
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length


## Height of the navmesh at a point of the ground plane, wherever the point's own height is.
func _walkable_y(p: Vector3) -> float:
	var best := INF
	var best_y := INF
	for y in [-3.0, 0.0, 3.0]:
		var q := NavigationServer3D.map_get_closest_point(mission.nav_map(), Vector3(p.x, y, p.z))
		var off := Vector2(q.x - p.x, q.z - p.z).length()
		if off < best:
			best = off
			best_y = q.y
	return best_y


## Walkable from the start through every waypoint, without a long way round between any two.
func _assert_route(route: Array[Vector2], label: String) -> void:
	var from := mission.specialist_spawns()[0].global_position
	for p in route:
		var to := _on_ground(p)
		var length := _path_length(from, to)
		assert_lt(length, from.distance_to(to) * 1.4 + 2.0, "%s: leg to %s" % [label, p])
		from = to


func test_bridge_valid() -> void:
	await _built()
	assert_eq(MissionValidator.validate(mission), PackedStringArray())


## Godot's path search gives up after 4096 polygons and then logs an engine error for a target
## nobody can reach (a click across the gorge once the bridge is down), so the navmesh stays
## well under that.
func test_navmesh_stays_small_enough_for_the_path_search() -> void:
	await _built()
	var polygons := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh.get_polygon_count()
	assert_between(polygons, 500, 2000)


func test_bridge_counts() -> void:
	await _load()
	assert_eq(mission.specialist_spawns().size(), 2)
	assert_eq(mission.guard_spawns().size(), 5)
	assert_eq(mission.patrol_routes().size(), 5)
	assert_eq(mission.guards().size(), 5)
	assert_not_null((mission.get_node("BridgeTarget") as Node3D))
	assert_not_null(mission.extraction())
	assert_not_null(mission.terrain())
	assert_eq(mission.bounds_rect, mission.terrain().spec.bounds)


func test_extraction_is_far_side_from_start() -> void:
	await _load()
	var start := mission.specialist_spawns()[0].global_position
	var bridge := (mission.get_node("BridgeTarget") as Node3D).global_position
	var out := mission.extraction().global_position
	assert_gt(out.distance_to(start), 60.0)
	assert_lt(start.x, bridge.x)
	assert_gt(out.x, bridge.x)


func test_guards_and_spawns_stand_on_the_ground() -> void:
	await _built()
	var guards := mission.guards()
	var spawns := mission.guard_spawns()
	for i in guards.size():
		var p := guards[i].global_position
		assert_almost_eq(Vector2(p.x, p.z), Vector2(spawns[i].global_position.x, spawns[i].global_position.z),
				Vector2.ONE * 0.001)
		assert_almost_eq(p.y, _walkable_y(p), 0.3, "%s height" % guards[i].name)
		assert_eq(guards[i].route_size(), mission.patrol_routes()[i].curve.point_count)
		for point in mission.guard_route(String(guards[i].name)):
			assert_almost_eq(point.y, _walkable_y(point), 0.3, "%s route height" % guards[i].name)
	for spawn in mission.specialist_spawns():
		var p := spawn.global_position
		assert_almost_eq(p.y, mission.ground_height(p.x, p.z), 0.01)
		assert_lt(p.y, -2.0, "the start is on the low plain, below the railway")


func test_guards_walk_their_routes_once_nav_is_built() -> void:
	await _load(true)
	var starts: Array[Vector3] = []
	for guard in mission.guards():
		starts.append(guard.global_position)
	mission.build_nav()
	await wait_seconds(1.0)
	for i in starts.size():
		var p := mission.guards()[i].global_position
		var walked := Vector2(p.x - starts[i].x, p.z - starts[i].z).length()
		assert_almost_eq(walked, 3.0, 0.6, "%s walks at 3 m/s" % mission.guards()[i].name)
		assert_eq(mission.guards()[i].brain.state, GuardBrain.State.PATROL)
		assert_almost_eq(p.y, mission.ground_height(p.x, p.z), 0.3, "on the ground")


func test_every_patrol_leg_is_walkable_without_a_detour() -> void:
	await _built()
	for guard in mission.guards():
		var route := mission.guard_route(String(guard.name))
		for i in route.size():
			var from := route[i]
			var to := route[(i + 1) % route.size()]
			assert_lt(_path_length(from, to), from.distance_to(to) * 1.15 + 0.5,
					"%s leg %d" % [guard.name, i])


func test_three_routes_lead_to_the_bridge() -> void:
	await _built()
	_assert_route(ROAD_ROUTE, "road")
	_assert_route(GORGE_ROUTE, "gorge path")
	_assert_route(HILL_ROUTE, "hill path")


func test_the_embankment_can_only_be_climbed_by_its_ramps() -> void:
	await _built()
	# Straight up the bank from the south plain to the track is 10 m; the way round is far longer.
	var length := _path_length(_on_ground(Vector2(-20, 10)), _on_ground(Vector2(-20, 0)))
	assert_gt(length, 18.0)
	assert_lt(length, 60.0, "but there is a way")


func test_a_walker_stays_on_the_ground_up_the_gorge_path() -> void:
	await _built()
	var walker: Specialist = mission.spawn_specialists()[0]
	walker.global_position = _on_ground(Vector2(-15, 10))
	walker.move_to(_on_ground(Vector2(-7, 1.5)))
	var worst := 0.0
	var arrived := [false]
	walker.arrived.connect(func(_u: Unit) -> void: arrived[0] = true)
	for i in 480:
		await get_tree().physics_frame
		var p := walker.global_position
		if i > 20:
			worst = maxf(worst, absf(p.y - mission.ground_height(p.x, p.z)))
		if arrived[0]:
			break
	assert_true(arrived[0], "reaches the abutment")
	assert_lt(worst, 0.3)
	assert_almost_eq(walker.global_position.y, 0.0, 0.25, "at rail level")


func test_the_embankment_hides_a_crawler_at_its_foot_from_the_track() -> void:
	await _built()
	var spec: Specialist = mission.spawn_specialists()[0]
	var guard: Guard = mission.guards()[2]
	guard.global_position = _on_ground(Vector2(-20, 0))
	guard.rotation.y = PI  # facing +z, down the south bank
	spec.global_position = _on_ground(Vector2(-20, 7))
	await wait_physics_frames(2)
	var vision := Vision.defaults()
	var seen := func() -> Vision.Zone: return Perception.sees(guard, spec, vision.target_height(spec.stance))
	assert_eq(seen.call(), Vision.Zone.FAR, "someone standing at the foot shows over the shoulder")
	spec.set_stance(Unit.Stance.CRAWLING)
	assert_eq(seen.call(), Vision.Zone.NONE, "lying down they are hidden")


func test_nothing_walks_in_the_gorge() -> void:
	await _built()
	for z in [-30.0, -12.0, 15.0, 32.0]:
		var bed := NavigationServer3D.map_get_closest_point(mission.nav_map(), Vector3(0, -11, z))
		assert_gt(bed.y, -5.0, "no navmesh on the gorge floor at z = %s" % z)
	assert_almost_eq(mission.ground_height(0, 20), -12.0, 3.0, "the gorge is deep")


func test_the_deck_joins_the_two_banks_at_rail_level() -> void:
	await _built()
	var west := _on_ground(Vector2(-8, 0))
	var east := _on_ground(Vector2(8, 0))
	assert_almost_eq(_path_length(west, east), 16.0, 0.5)
	var mid := NavigationServer3D.map_get_closest_point(mission.nav_map(), Vector3.ZERO)
	assert_almost_eq(mid, Vector3.ZERO, Vector3(0.1, 0.1, 0.1))
	for point in mission.guard_route("Guard4"):
		assert_almost_eq(point.y, 0.0, 0.05, "the sentry's route is at rail level")


func test_broken_bridge_stubs_jut_over_the_gorge_without_collision() -> void:
	await _built()
	mission.break_bridge()
	var stubs := mission.get_node("Nav/BridgeBroken")
	var over_gorge := 0
	for mesh in stubs.find_children("*", "MeshInstance3D", true, false):
		assert_false(mesh.get_parent() is CollisionObject3D)
		if absf((mesh as MeshInstance3D).global_position.x) < Mission.BANK_EDGE_X:
			over_gorge += 1
	assert_eq(over_gorge, 2, "one stub past each bank edge")
	assert_eq(stubs.find_children("*", "CSGShape3D", true, false).size(), 0, "nothing the bake or physics sees")
	assert_false(mission.get_node("Scenery/GirderN").visible)
	await get_tree().process_frame
	await get_tree().process_frame
	var west := mission.specialist_spawns()[0].global_position
	var east := mission.extraction().global_position
	assert_eq(_path_length(west, east), INF, "the gorge is impassable")
	mission.repair_bridge()
	assert_true(mission.get_node("Scenery/GirderN").visible)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lt(_path_length(west, east), 200.0, "and whole again after a repair")


func test_a_walker_caught_by_the_blast_order_stops_at_the_bank() -> void:
	await _built()
	var walker: Specialist = mission.spawn_specialists()[0]
	walker.global_position = _on_ground(Vector2(-12, 0))
	await wait_physics_frames(2)
	walker.move_to(Vector3(12, 0, 0))
	for i in 120:
		await get_tree().physics_frame
		if walker.global_position.x > -9.0:
			break
	assert_gt(walker.global_position.x, -9.5, "on the approach, heading for the bridge")
	mission.break_bridge()
	await wait_seconds(4.0)
	var p := walker.global_position
	assert_eq(walker.velocity, Vector3.ZERO, "stopped")
	assert_lte(p.x, -Mission.BANK_EDGE_X + 0.3, "on the west bank, not out over the gorge")
	assert_gt(p.x, -9.5, "at the edge, having gone as far as it could")
	assert_almost_eq(p.y, 0.0, 0.25, "standing on the abutment")


func test_the_vision_overlay_leaves_the_embankment_foot_dark() -> void:
	await _built()
	var guard: Guard = mission.guards()[2]
	guard.global_position = _on_ground(Vector2(-20, 0))
	guard.rotation.y = PI  # facing +z, down the south bank
	await wait_physics_frames(2)
	var ground := func(x: float, z: float) -> float: return mission.ground_height(x, z)
	var near := Perception.ground_samples(guard, guard.vision.near_range, 9, 0.5, guard.vision.target_height_crawling, ground)
	var row: PackedVector3Array = near["points"][4]  # straight down the bank
	var seen: PackedByteArray = near["visible"][4]
	var hidden := 0
	for j in row.size():
		assert_almost_eq(row[j].y, mission.ground_height(row[j].x, row[j].z), 0.001, "draped on the land")
		if row[j].z <= 2.0:
			assert_eq(seen[j], 1, "the track bed at z = %.1f is in view" % row[j].z)
		elif row[j].z >= 5.0:
			hidden += 1 - seen[j]
	assert_gte(hidden, 2, "the bottom of the bank is out of sight for a crawler")


func test_whoever_stands_on_the_span_when_it_blows_goes_down_with_it() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specialists)
	var sentry: Guard = mission.guards()[3]
	# The charge at the west end: its 8 m blast does not reach the east end of the span.
	sentry.global_position = Vector3(4.2, 0, 0)
	specialists[0].global_position = Vector3(7.0, 0, 0)   # on the east abutment, off the span
	specialists[1].global_position = Vector3(-30, mission.ground_height(-30, 30), 30)
	var track_guard: Guard = mission.guards()[2]
	track_guard.global_position = Vector3(4.0, mission.ground_height(4.0, 20.0), 20.0)  # in the gorge's line, not on the span
	await wait_physics_frames(2)
	assert_true(mission.on_span(sentry.global_position))
	assert_false(mission.on_span(specialists[0].global_position))
	assert_false(mission.on_span(Vector3(0, -9, 0)), "the gorge floor under the bridge is not the span")
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	mission.add_child(charge)
	charge.global_position = Vector3(-4.5, 0, 0)
	charge.advance(0.1)
	await wait_physics_frames(2)
	assert_true(rules.objectives_done())
	assert_false(is_instance_valid(sentry) and sentry.alive, "the sentry on the span fell with it")
	assert_true(specialists[0].alive, "the abutment holds")
	assert_true(track_guard.alive)


# --- Cut off: the bridge is down and someone can no longer reach the extraction ---

func _rules_for(specialists: Array[Specialist]) -> MissionRules:
	var rules := MissionRules.new()
	add_child_autofree(rules)
	rules.setup(mission, specialists)
	return rules


func _blow(at: Vector3) -> void:
	var charge := PlantedCharge.new()
	charge.fuse_left = 0.0
	mission.add_child(charge)
	charge.global_position = at
	charge.advance(0.1)
	await wait_physics_frames(4)


func test_blowing_the_bridge_with_someone_left_behind_fails_the_mission() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := _rules_for(specialists)
	specialists[0].global_position = _on_ground(Vector2(20, 0))    # across
	specialists[1].global_position = _on_ground(Vector2(-30, 30))  # still on the west bank
	await wait_physics_frames(2)
	assert_eq(rules.loss_reason(), "", "nothing lost yet")
	await _blow(Vector3(-4.5, 0, 0))
	assert_true(rules.objectives_done())
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), MissionRules.BRIDGE_CUT_OFF_TEXT)
	assert_true(specialists[0].alive and specialists[1].alive, "nobody died; they are just stranded")


func test_blowing_the_bridge_with_both_across_plays_on() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := _rules_for(specialists)
	specialists[0].global_position = _on_ground(Vector2(20, 0))
	specialists[1].global_position = _on_ground(Vector2(24, 0))
	await wait_physics_frames(2)
	await _blow(Vector3(-4.5, 0, 0))
	assert_true(rules.objectives_done())
	assert_eq(rules.result, MissionRules.Result.RUNNING)
	assert_eq(rules.loss_reason(), "")


func test_a_death_is_named_as_the_reason_for_a_loss() -> void:
	await _built()
	var specialists := mission.spawn_specialists()
	var rules := _rules_for(specialists)
	specialists[1].take_damage(1000)
	rules.evaluate()
	assert_eq(rules.result, MissionRules.Result.LOST)
	assert_eq(rules.loss_reason(), MissionRules.DEATH_TEXT)


# --- Props that look solid are solid ---

func test_yard_clutter_and_the_girders_block_sight_and_feet() -> void:
	await _built()
	var blockers := mission.get_node("Nav").find_children("PropBlocker*", "StaticBody3D", true, false)
	assert_gte(blockers.size(), 5, "barrels, boxes and the tent")
	for body in blockers:
		var p := (body as Node3D).global_position
		var near := NavigationServer3D.map_get_closest_point(mission.nav_map(), p)
		assert_gt(Vector2(near.x - p.x, near.z - p.z).length(), 0.4, "%s is cut out of the navmesh" % body.name)
		assert_false(Perception.line_clear(mission, p + Vector3(-2.6, 0.0, 0), p + Vector3(2.6, 0.0, 0)),
				"%s hides someone lying behind it" % body.name)
	# A girder runs along each side of the deck: lying on the deck you are hidden from the side.
	assert_false(Perception.line_clear(mission, Vector3(0, 0.3, 0), Vector3(0, 0.3, 6)))
	assert_false(Perception.line_clear(mission, Vector3(0, 0.3, 0), Vector3(0, 0.3, -6)))
	assert_true(Perception.line_clear(mission, Vector3(0, 1.5, 0), Vector3(0, 1.5, 6)), "standing, you show over it")
	mission.break_bridge()
	await wait_physics_frames(3)
	assert_true(Perception.line_clear(mission, Vector3(0, 0.3, 0), Vector3(0, 0.3, 6)), "gone with the span")


func test_every_quarter_of_the_map_can_be_walked_to() -> void:
	await _built()
	var start := mission.specialist_spawns()[0].global_position
	for corner in [Vector2(-45, -30), Vector2(40, -30), Vector2(40, 30), Vector2(-20, 34)]:
		assert_lt(_path_length(start, _on_ground(corner)), 400.0, "from the start to %s" % corner)
