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
	var mission: Node3D = load("res://scenes/missions/bridge.tscn").instantiate()
	add_child_autofree(mission)
	guard.global_position = Vector3(-30, 0, 0)
	target.global_position = Vector3(-22, 0, 0)
	guard.rotation.y = -PI / 2.0 # face +x, through WallMid at x = -26
	await _settle()
	assert_eq(Perception.sees(guard, target, 1.5), Vision.Zone.NONE)
