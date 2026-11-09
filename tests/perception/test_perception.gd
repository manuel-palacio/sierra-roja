extends GutTest

var guard: Unit
var target: Node3D


func before_each() -> void:
	guard = Unit.new()
	add_child_autofree(guard)
	target = Node3D.new()
	add_child_autofree(target)
	target.global_position = Vector3(0, 0, -10)


func _wall(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = pos
	body.collision_layer = Perception.WORLD_MASK
	return body


func _settle() -> void:
	await wait_physics_frames(2)


func test_open_ground_sees_target() -> void:
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.FAR)


func test_wall_blocks() -> void:
	_wall(Vector3(0, 1.5, -5), Vector3(6, 3, 0.5))
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NONE)


func test_low_wall_hides_crawler_not_stander() -> void:
	_wall(Vector3(0, 0.5, -3), Vector3(6, 1.0, 0.5))
	target.global_position = Vector3(0, 0, -5)
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NEAR, "stander seen over a 1 m wall")
	assert_eq(Perception.sees(guard, target, 0.3), Vision.Zone.NONE, "crawler hidden behind it")


func test_platform_above_sight_line_is_hidden() -> void:
	# Raised block 3 m high; target stands on top, behind the edge.
	_wall(Vector3(0, 1.5, -6), Vector3(6, 3, 6))
	target.global_position = Vector3(0, 3, -8)
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NONE)


func test_units_do_not_block_sight() -> void:
	var other := Unit.new()
	add_child_autofree(other)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	other.add_child(shape)
	other.global_position = Vector3(0, 0, -5)
	await _settle()
	assert_eq(other.collision_layer & Perception.WORLD_MASK, 0, "units are not on the world layer")
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.FAR)


func test_guard_facing_away_does_not_see() -> void:
	guard.rotation.y = PI
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NONE)


func test_polygon_open_ground() -> void:
	await _settle()
	var poly := Perception.polygon(guard, 14.0, 24)
	assert_eq(poly.size(), 25)
	assert_eq(poly[0], guard.global_position)
	for i in range(1, poly.size()):
		assert_almost_eq(poly[i].y, 0.0, 0.001)
		assert_almost_eq(Vector2(poly[i].x, poly[i].z).length(), 14.0, 0.01)


func test_polygon_clipped_by_wall() -> void:
	_wall(Vector3(0, 1.5, -5), Vector3(20, 3, 0.5))
	await _settle()
	var poly := Perception.polygon(guard, 14.0, 24)
	for i in range(1, poly.size()):
		assert_lt(Vector2(poly[i].x, poly[i].z).length(), 8.0)


func test_bridge_csg_walls_are_on_world_layer() -> void:
	var mission: Node3D = load("res://tests/fixtures/flat_bridge.tscn").instantiate()
	add_child_autofree(mission)
	guard.global_position = Vector3(-30, 0, 0)
	target.global_position = Vector3(-22, 0, 0)
	guard.rotation.y = -PI / 2.0 # face +x, through WallMid at x = -26
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NONE)


# --- Ground samples: what the vision overlay draws ---

func _flat_ground(_x: float, _z: float) -> float:
	return 0.0


func test_ground_samples_cover_the_cone_on_open_ground() -> void:
	await _settle()
	var s := Perception.ground_samples(guard, 6.0, 9, 1.0, 0.3, _flat_ground)
	var points: Array = s["points"]
	var visible: Array = s["visible"]
	assert_eq(points.size(), 9, "one row per ray")
	assert_eq(visible.size(), 9)
	for i in points.size():
		var row: PackedVector3Array = points[i]
		assert_eq(row.size(), 7, "the guard's feet, then every metre out to 6 m")
		assert_eq(row[0], guard.global_position)
		assert_almost_eq(Vector2(row[-1].x, row[-1].z).length(), 6.0, 0.001)
		for j in row.size():
			assert_almost_eq(row[j].y, 0.0, 0.001, "on the ground")
			assert_eq(visible[i][j], 1, "nothing in the way")
	var first: PackedVector3Array = points[0]
	var last: PackedVector3Array = points[-1]
	assert_almost_eq(absf(rad_to_deg(Vector2(first[-1].x, first[-1].z).angle_to(Vector2(last[-1].x, last[-1].z)))),
			80.0, 0.5, "the rows span the 80 degree cone")


func test_ground_samples_can_start_away_from_the_guard() -> void:
	await _settle()
	var s := Perception.ground_samples(guard, 14.0, 5, 2.0, 1.5, _flat_ground, null, 6.0)
	var row: PackedVector3Array = s["points"][2]  # the middle ray, straight ahead (-z)
	var distances: Array[float] = []
	for p in row:
		distances.append(snappedf(-p.z, 0.01))
	assert_eq(distances, [6.0, 8.0, 10.0, 12.0, 14.0] as Array[float])


func test_ground_samples_follow_the_ground() -> void:
	await _settle()
	var slope := func(_x: float, z: float) -> float: return z * 0.1
	var s := Perception.ground_samples(guard, 6.0, 3, 2.0, 0.3, slope)
	for row: PackedVector3Array in s["points"]:
		for j in range(1, row.size()):
			assert_almost_eq(row[j].y, row[j].z * 0.1, 0.001)


func test_a_low_wall_hides_the_ground_behind_it_from_a_crawlers_height_only() -> void:
	_wall(Vector3(0, 0.5, -3), Vector3(20, 1, 0.5))
	await _settle()
	var near := Perception.ground_samples(guard, 6.0, 5, 1.0, 0.3, _flat_ground)
	var row: PackedVector3Array = near["points"][2]
	var seen: PackedByteArray = near["visible"][2]
	for j in row.size():
		if -row[j].z < 2.5:
			assert_eq(seen[j], 1, "in front of the wall at %s" % row[j])
		elif -row[j].z > 3.5:
			assert_eq(seen[j], 0, "a crawler behind the wall at %s is hidden" % row[j])
	var far := Perception.ground_samples(guard, 14.0, 5, 1.0, 1.5, _flat_ground, null, 6.0)
	row = far["points"][2]
	seen = far["visible"][2]
	for j in row.size():
		assert_eq(seen[j], 1, "a stander 2 m and more past the wall shows over it, at %s" % row[j])
