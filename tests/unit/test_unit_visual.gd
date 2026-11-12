extends GutTest
## What a unit looks like: a soldier in its uniform and kit, doing what the unit is doing.

const GUARD := "res://scenes/units/guard.tscn"
const DYNAMITER := "res://scenes/units/specialist.tscn"
const MARKSMAN := "res://scenes/units/marksman.tscn"


func _unit(scene: String) -> Unit:
	var unit: Unit = load(scene).instantiate()
	add_child_autofree(unit)
	unit.set_physics_process(false)
	return unit


func _body_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			out.append(node)
	return out


func _gear(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node in root.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		if node.get_parent() is BoneAttachment3D:
			out.append(node)
	return out


func _uniforms(root: Node) -> Dictionary:
	var out := {}
	for mesh in _body_meshes(root):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			out[material.albedo_texture.resource_path.get_file()] = true
	return out


## Height of the head bone above the unit's feet, as the animation has it now.
func _head_height(unit: Node3D) -> float:
	var skeleton := unit.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := skeleton.find_bone("DEF-head")
	return (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin.y - unit.global_position.y


func _settle(unit: Unit, seconds := 0.6) -> void:
	var visual := unit.get_node("UnitVisual") as UnitVisual
	var player := unit.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	visual._process(0.0)
	player.advance(seconds)
	visual._process(seconds)
	await get_tree().process_frame


func test_units_are_human_soldiers_not_blocks() -> void:
	for scene in [GUARD, DYNAMITER, MARKSMAN]:
		var unit := _unit(scene)
		assert_eq(_body_meshes(unit).size(), 1, "one skinned body on %s" % scene)
		assert_eq(unit.find_children("*", "Skeleton3D", true, false).size(), 1)
		await _settle(unit)
		assert_between(_head_height(unit), 1.8, 2.2, "a little over life size, to read from above")


func test_each_unit_wears_its_own_uniform() -> void:
	assert_eq(_uniforms(_unit(GUARD)).keys(), ["uniform-guard.png"])
	assert_eq(_uniforms(_unit(DYNAMITER)).keys(), ["uniform-dynamiter.png"])
	assert_eq(_uniforms(_unit(MARKSMAN)).keys(), ["uniform-marksman.png"])


func test_each_unit_carries_its_own_kit_on_its_bones() -> void:
	var counts := {}
	for scene in [GUARD, DYNAMITER, MARKSMAN]:
		var unit := _unit(scene)
		var kit: StringName = (unit.get_node("UnitVisual") as UnitVisual).kit
		var pieces := _gear(unit)
		assert_eq(pieces.size(), (SoldierGear.KITS[kit] as Array).size(), "every piece of the %s kit" % kit)
		for piece in pieces:
			assert_true((piece.get_parent() as BoneAttachment3D).bone_idx >= 0, "rides a real bone")
			assert_not_null(piece.get_active_material(0))
		counts[kit] = pieces.size()
	assert_eq(counts.size(), 3, "three different kits")


func test_a_helmet_sits_on_the_head_and_follows_it_down() -> void:
	var unit := _unit(GUARD)
	await _settle(unit)
	var helmet := _gear(unit)[0]
	assert_almost_eq(helmet.global_position.y - unit.global_position.y, _head_height(unit) + 0.12, 0.15,
			"on the head while standing")
	unit.set_stance(Unit.Stance.CRAWLING)
	await _settle(unit)
	assert_lt(helmet.global_position.y - unit.global_position.y, 1.0, "and with it when the guard is down")


func test_the_animation_follows_what_the_unit_does() -> void:
	var unit := _unit(DYNAMITER)
	var visual := unit.get_node("UnitVisual") as UnitVisual
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.IDLE)
	unit.velocity = Vector3(0, 0, -unit.stats.walk_speed)
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.WALK)
	unit.velocity = Vector3(unit.stats.run_speed, 0, 0)
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.RUN)
	unit.set_stance(Unit.Stance.CRAWLING)
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.CRAWL)
	unit.velocity = Vector3.ZERO
	unit.take_damage(1000)
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.DIE)


func test_moving_animations_loop_and_dying_does_not() -> void:
	var unit := _unit(GUARD)
	var player := unit.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in [UnitVisual.IDLE, UnitVisual.WALK, UnitVisual.RUN, UnitVisual.CRAWL]:
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, String(clip))
	assert_eq(player.get_animation(UnitVisual.DIE).loop_mode, Animation.LOOP_NONE)


func test_a_crawling_unit_lies_flat_and_only_works_its_limbs_while_moving() -> void:
	var unit := _unit(MARKSMAN)
	var visual := unit.get_node("UnitVisual") as UnitVisual
	var player := unit.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	unit.set_stance(Unit.Stance.CRAWLING)
	await _settle(unit)
	assert_lt(_head_height(unit), 0.8, "head near the ground")
	assert_gt(_head_height(unit), 0.0, "not under it")
	assert_eq(player.speed_scale, 0.0, "lying still")
	unit.velocity = Vector3(0, 0, -unit.stats.crawl_speed)
	visual._process(0.0)
	assert_gt(player.speed_scale, 0.0, "crawling along")
	unit.set_stance(Unit.Stance.STANDING)
	unit.velocity = Vector3.ZERO
	await _settle(unit)
	assert_gt(_head_height(unit), 1.8, "back on its feet")
	assert_eq(player.speed_scale, 1.0)


func test_a_body_is_the_guard_fallen_in_uniform_and_kit() -> void:
	var body: Body = load(Body.SCENE).instantiate()
	add_child_autofree(body)
	await get_tree().process_frame
	assert_eq(_uniforms(body).keys(), ["uniform-guard.png"])
	assert_eq(_gear(body).size(), (SoldierGear.KITS[&"guard"] as Array).size(), "helmet and rifle still on it")
	var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(player.assigned_animation, String(UnitVisual.DIE))
	assert_almost_eq(player.current_animation_position, player.get_animation(UnitVisual.DIE).length, 0.05, "already down")
	assert_false(player.is_playing(), "and staying down")
	assert_lt(_head_height(body), 0.7, "lying on the ground")


## Ground that the navmesh floats 0.3 m above: the unit stands at navmesh height and its model is
## let down onto what is drawn.
func test_the_model_stands_on_the_drawn_ground() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10, 1, 10)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)  # top at y = 0
	var unit := _unit(DYNAMITER)
	unit.global_position = Vector3(0, 0.3, 0)
	await wait_physics_frames(3)
	await get_tree().process_frame
	var model := unit.get_node("Model") as Node3D
	assert_almost_eq(model.global_position.y, 0.0, 0.02, "feet on the floor")
	unit.global_position = Vector3(0, 0.9, 0)
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_almost_eq(model.position.y, -UnitVisual.MAX_GROUND_SHIFT, 0.001, "but never moved far from the unit")
	unit.global_position = Vector3(50, 0.0, 0)  # nothing under it at all
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_almost_eq(model.position.y, 0.0, 0.001)


func test_every_part_of_a_unit_shows_through_what_hides_it() -> void:
	for scene in [GUARD, DYNAMITER, MARKSMAN]:
		var unit := _unit(scene)
		var meshes := _body_meshes(unit) + _gear(unit)
		assert_gt(meshes.size(), 3)
		for mesh in meshes:
			for i in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(i) as BaseMaterial3D
				assert_eq(material.stencil_mode, BaseMaterial3D.STENCIL_MODE_XRAY, "%s on %s" % [mesh.name, scene])


func test_guards_and_specialists_have_different_silhouettes() -> void:
	var colour := func(scene: String) -> Color:
		return (_body_meshes(_unit(scene))[0].get_active_material(0) as BaseMaterial3D).stencil_color
	var guard: Color = colour.call(GUARD)
	var dynamiter: Color = colour.call(DYNAMITER)
	assert_gt(guard.r, guard.b, "guards warm")
	assert_gt(dynamiter.b, dynamiter.r, "specialists cool")
	assert_eq(dynamiter, colour.call(MARKSMAN))


# --- Weapons in use ---

func _pieces(unit: Node, when: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for piece in _gear(unit):
		if piece.get_meta("when", &"") == when:
			out.append(piece)
	return out


func test_weapons_are_slung_until_used() -> void:
	var guard := _unit(GUARD)
	assert_gt(_pieces(guard, &"slung").size(), 0, "a rifle on the back")
	assert_gt(_pieces(guard, &"rifle").size(), 0, "and the same rifle for the hands")
	for piece in _pieces(guard, &"slung"):
		assert_true(piece.visible)
	for piece in _pieces(guard, &"rifle"):
		assert_false(piece.visible)
	var marksman := _unit(MARKSMAN)
	assert_gt(_pieces(marksman, &"rifle").size(), 0)
	assert_gt(_pieces(marksman, &"pistol").size(), 0)
	assert_gt(_pieces(_unit(DYNAMITER), &"pistol").size(), 0)
	assert_gt(_pieces(_unit(DYNAMITER), &"knife").size(), 0)


func test_a_shot_is_shown_weapon_in_hand_then_put_away() -> void:
	var unit := _unit(MARKSMAN)
	var visual := unit.get_node("UnitVisual") as UnitVisual
	visual._process(0.0)
	unit.acted.emit(&"rifle", Vector3(0, 0, -10))
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.SHOOT)
	for piece in _pieces(unit, &"rifle"):
		assert_true(piece.visible, "rifle in the hands")
	for piece in _pieces(unit, &"slung"):
		assert_false(piece.visible, "not on the back at the same time")
	for piece in _pieces(unit, &"pistol"):
		assert_false(piece.visible)
	visual._process(UnitVisual.ACTION_SECONDS + 0.05)
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.IDLE)
	for piece in _pieces(unit, &"rifle"):
		assert_false(piece.visible)
	for piece in _pieces(unit, &"slung"):
		assert_true(piece.visible)


func test_a_knife_is_shown_as_a_stab() -> void:
	var unit := _unit(DYNAMITER)
	var visual := unit.get_node("UnitVisual") as UnitVisual
	unit.acted.emit(&"knife", Vector3(1, 0, 0))
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.STAB)
	for piece in _pieces(unit, &"knife"):
		assert_true(piece.visible)


func test_a_unit_lying_down_fires_from_where_it_lies() -> void:
	var unit := _unit(MARKSMAN)
	var visual := unit.get_node("UnitVisual") as UnitVisual
	unit.set_stance(Unit.Stance.CRAWLING)
	visual._process(0.0)
	unit.acted.emit(&"rifle", Vector3(0, 0, -10))
	visual._process(0.0)
	assert_eq(visual.current_animation(), UnitVisual.CRAWL, "it does not spring to its feet")
	for piece in _pieces(unit, &"rifle"):
		assert_true(piece.visible, "but the rifle is out")


func test_a_guard_killed_now_is_seen_to_fall() -> void:
	var guard := _unit(GUARD)
	var holder := guard.get_parent()
	guard.take_damage(1000)
	var bodies := get_tree().get_nodes_in_group(Body.GROUP)
	assert_eq(bodies.size(), 1)
	var body := bodies[0] as Body
	await get_tree().process_frame
	var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_true(player.is_playing(), "falling, from the start of its death")
	assert_lt(player.current_animation_position, 0.3)
	assert_gt(_head_height(body), 1.0, "still on the way down")
	assert_eq(body.get_parent(), holder)
	body.free()


# --- Where silhouettes cannot be relied on ---

func test_guards_get_a_ground_ring_only_when_markers_are_asked_for() -> void:
	assert_false(UnitVisual.always_markers, "off unless the page asks (?markers=1)")
	assert_null(_unit(GUARD).get_node_or_null("LocatorRing"))
	UnitVisual.always_markers = true
	var guard := _unit(GUARD)
	UnitVisual.always_markers = false
	await get_tree().process_frame
	var ring := guard.get_node_or_null("LocatorRing") as SelectionRing
	assert_not_null(ring, "a ring that shows through whatever stands in front")
	if ring != null:
		assert_true((ring.material_override as StandardMaterial3D).no_depth_test)
		assert_gt(ring.color.r, ring.color.b, "in the guards' warm colour")
