extends GutTest

var user: Specialist
var noises: Array = []


func before_each() -> void:
	user = _spawn_specialist(PackedStringArray(["knife", "charge", "pistol", "carry"]), Vector3.ZERO)
	noises.clear()
	NoiseBus.noise_emitted.connect(_on_noise)


func after_each() -> void:
	# Bodies made by dying guards are not autofreed; keep them out of the next test.
	for b in _bodies():
		b.free()
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()
	NoiseBus.noise_emitted.disconnect(_on_noise)


func _on_noise(pos: Vector3, radius: float) -> void:
	noises.append([pos, radius])


func _spawn_specialist(ids: PackedStringArray, pos: Vector3) -> Specialist:
	var s := Specialist.new()
	s.ability_ids = ids
	add_child_autofree(s)
	s.global_position = pos
	return s


func _guard(pos: Vector3) -> Guard:
	var g := load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(g)
	g.global_position = pos
	return g


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = pos
	body.collision_layer = Perception.WORLD_MASK


func _bodies() -> Array:
	return get_tree().get_nodes_in_group(Body.GROUP)


func _body_at(pos: Vector3) -> Body:
	var b := load("res://scenes/units/body.tscn").instantiate() as Body
	add_child_autofree(b)
	b.global_position = pos
	return b


func test_knife_kills_in_range_silently() -> void:
	var g := _guard(Vector3(1.2, 0, 0))
	await wait_physics_frames(2)
	var knife: Ability = user.abilities["knife"]
	assert_true(knife.can_use(user, g))
	knife.use(user, g)
	assert_false(g.alive)
	assert_eq(noises.size(), 0, "a knife kill makes no noise")
	assert_eq(_bodies().size(), 1, "the guard is replaced by a body")
	assert_eq((_bodies()[0] as Body).global_position, Vector3(1.2, 0, 0))


func test_knife_out_of_range_refused() -> void:
	var g := _guard(Vector3(1.6, 0, 0))
	await wait_physics_frames(2)
	var knife: Ability = user.abilities["knife"]
	assert_false(knife.can_use(user, g))
	knife.use(user, g)
	assert_true(g.alive)


func test_knife_through_wall_refused() -> void:
	_wall(Vector3(0.7, 1.5, 0), Vector3(0.2, 3, 4))
	var g := _guard(Vector3(1.2, 0, 0))
	await wait_physics_frames(2)
	assert_false((user.abilities["knife"] as Ability).can_use(user, g))


func test_rifle_kills_and_makes_noise_35() -> void:
	user.grant_abilities(PackedStringArray(["rifle"]))
	var g := _guard(Vector3(0, 0, -30))
	await wait_physics_frames(2)
	var rifle: Ability = user.abilities["rifle"]
	assert_eq(rifle.ammo, 5)
	rifle.use(user, g)
	assert_false(g.alive)
	assert_eq(rifle.ammo, 4)
	assert_eq(noises.size(), 1)
	assert_eq(noises[0][1], 35.0)
	assert_eq(_bodies().size(), 1)


func test_rifle_out_of_range_refused() -> void:
	user.grant_abilities(PackedStringArray(["rifle"]))
	var g := _guard(Vector3(0, 0, -41))
	await wait_physics_frames(2)
	assert_false((user.abilities["rifle"] as Ability).can_use(user, g))


func test_rifle_stops_at_zero_ammo() -> void:
	user.grant_abilities(PackedStringArray(["rifle"]))
	var rifle: Ability = user.abilities["rifle"]
	rifle.ammo = 1
	var a := _guard(Vector3(0, 0, -10))
	var b := _guard(Vector3(3, 0, -10))
	await wait_physics_frames(2)
	rifle.use(user, a)
	assert_eq(rifle.ammo, 0)
	assert_false(rifle.can_use(user, b))
	rifle.use(user, b)
	assert_true(b.alive)
	assert_eq(noises.size(), 1, "the refused shot makes no noise")


func test_rifle_blocked_by_wall() -> void:
	user.grant_abilities(PackedStringArray(["rifle"]))
	_wall(Vector3(0, 1.5, -5), Vector3(6, 3, 0.5))
	var g := _guard(Vector3(0, 0, -10))
	await wait_physics_frames(2)
	var rifle: Ability = user.abilities["rifle"]
	assert_false(rifle.can_use(user, g))
	rifle.use(user, g)
	assert_true(g.alive)
	assert_eq(rifle.ammo, 5)


func test_pistol_two_shots_to_kill_noise_20() -> void:
	var g := _guard(Vector3(0, 0, -10))
	await wait_physics_frames(2)
	var pistol: Ability = user.abilities["pistol"]
	assert_eq(pistol.ammo, 8)
	pistol.use(user, g)
	assert_true(g.alive)
	assert_eq(g.hp, 50)
	pistol.use(user, g)
	assert_false(g.alive)
	assert_eq(noises.size(), 2)
	assert_eq(noises[0][1], 20.0)
	assert_eq(pistol.ammo, 6)


func test_charge_detonates_after_10s() -> void:
	var spec := _spawn_specialist(PackedStringArray(), Vector3(20, 0, 0))
	var charge: Ability = user.abilities["charge"]
	assert_false(charge.can_use(user, Vector3(2.5, 0, 0)), "out of plant range")
	assert_true(charge.can_use(user, Vector3(1.5, 0, 0)))
	charge.use(user, Vector3(1.5, 0, 0))
	var planted := get_tree().get_nodes_in_group(PlantedCharge.GROUP)[0] as PlantedCharge
	assert_eq(planted.global_position, Vector3(1.5, 0, 0))
	watch_signals(planted)
	planted.advance(9.9)
	assert_signal_not_emitted(planted, "detonated")
	assert_eq(noises.size(), 0)
	planted.advance(0.2)
	assert_signal_emitted_with_parameters(planted, "detonated", [Vector3(1.5, 0, 0)])
	assert_eq(noises.size(), 1)
	assert_eq(noises[0][1], 80.0)
	assert_true(spec.alive, "20 m away is outside the 8 m blast")


func test_blast_kills_nearby_specialist() -> void:
	var other := _spawn_specialist(PackedStringArray(), Vector3(7, 0, 0))
	var far := _spawn_specialist(PackedStringArray(), Vector3(9, 0, 0))
	var g := _guard(Vector3(0, 0, 6))
	var body := _body_at(Vector3(2, 0, 2))
	var planted := PlantedCharge.new()
	add_child_autofree(planted)
	planted.global_position = Vector3.ZERO
	planted.fuse_left = 1.0
	planted.advance(1.0)
	assert_false(user.alive, "the planter standing in the blast dies too")
	assert_false(other.alive)
	assert_true(far.alive)
	assert_false(g.alive)
	assert_true(is_instance_valid(body) and body.is_in_group(Body.GROUP), "bodies survive the blast")
	assert_false(body.found)
	assert_eq(_bodies().size(), 2, "the dead guard left a body too")


func test_blast_ignores_walls() -> void:
	_wall(Vector3(3, 1.5, 0), Vector3(0.5, 3, 10))
	var g := _guard(Vector3(6, 0, 0))
	var planted := PlantedCharge.new()
	add_child_autofree(planted)
	planted.global_position = Vector3(0, 0, 0)
	await wait_physics_frames(2)
	planted.advance(10.0)
	assert_false(g.alive)


func test_planted_charge_round_trips_state() -> void:
	var planted := PlantedCharge.new()
	add_child_autofree(planted)
	planted.global_position = Vector3(4, 0, -2)
	planted.fuse_left = 3.5
	var d := JSON.parse_string(JSON.stringify(planted.save_state())) as Dictionary
	var copy := PlantedCharge.new()
	add_child_autofree(copy)
	copy.load_state(d)
	assert_eq(copy.fuse_left, 3.5)
	assert_eq(copy.global_position, Vector3(4, 0, -2))


func test_ability_round_trips_state() -> void:
	var rifle := AbilityKit.create("rifle")
	rifle.ammo = 2
	var d := JSON.parse_string(JSON.stringify(rifle.save_state())) as Dictionary
	var copy := AbilityKit.create(d["id"])
	copy.load_state(d)
	assert_eq(copy.id, &"rifle")
	assert_eq(copy.ammo, 2)


func test_carry_moves_body_with_carrier() -> void:
	var body := _body_at(Vector3(1, 0, 0))
	var carry: Ability = user.abilities["carry"]
	assert_true(carry.can_use(user, body))
	carry.use(user, body)
	assert_eq(body.carried_by, user)
	user.global_position = Vector3(5, 0, 5)
	await wait_physics_frames(2)
	assert_eq(body.global_position, Vector3(5, 0, 5))


func test_carry_out_of_range_refused() -> void:
	var body := _body_at(Vector3(1.6, 0, 0))
	assert_false((user.abilities["carry"] as Ability).can_use(user, body))


func test_carrying_forces_walk() -> void:
	var body := _body_at(Vector3(1, 0, 0))
	var carry: Ability = user.abilities["carry"]
	carry.use(user, body)
	assert_false(user.can_run)
	user.move_to(Vector3(10, 0, 0), true)
	assert_almost_eq(user.current_speed(), user.stats.walk_speed, 0.001)
	carry.use(user, null)
	assert_true(user.can_run, "dropping restores running")
	assert_null(body.carried_by)


func test_marksman_has_no_carry() -> void:
	var marksman := _spawn_specialist(PackedStringArray(["rifle", "pistol"]), Vector3.ZERO)
	assert_true(marksman.has_ability("rifle"))
	assert_true(marksman.has_ability("pistol"))
	assert_false(marksman.has_ability("carry"))
	assert_false(marksman.has_ability("knife"))
	assert_true(user.has_ability("carry"))
	assert_false(user.has_ability("rifle"))


func test_dynamiter_scene_has_its_abilities() -> void:
	var s := load("res://scenes/units/specialist.tscn").instantiate() as Specialist
	add_child_autofree(s)
	for id in ["knife", "charge", "pistol", "carry"]:
		assert_true(s.has_ability(id), id)
	assert_false(s.has_ability("rifle"))


func test_dropped_body_stays_discoverable() -> void:
	var body := _body_at(Vector3(1, 0, 0))
	var carry: Ability = user.abilities["carry"]
	carry.use(user, body)
	user.global_position = Vector3(4, 0, 0)
	carry.use(user, null)
	await wait_physics_frames(2)
	assert_eq(body.global_position, Vector3(4, 0, 0))
	assert_true(body.is_in_group(Body.GROUP))
	assert_false(body.found)
	assert_null(body.carried_by)
	var g := _guard(Vector3(4, 0, 5))
	await wait_physics_frames(2)
	assert_ne(Perception.sees(g, body, Vision.defaults().target_height_crawling), Vision.Zone.NONE,
			"a guard can still see it")


func test_carrier_death_drops_body_where_they_fell() -> void:
	var body := _body_at(Vector3(1, 0, 0))
	(user.abilities["carry"] as Ability).use(user, body)
	user.global_position = Vector3(6, 0, 3)
	user.take_damage(100)
	assert_false(user.alive)
	assert_null(body.carried_by)
	assert_null(user.carrying)
	await wait_physics_frames(2)
	assert_eq(body.global_position, Vector3(6, 0, 3))
	assert_true(body.is_in_group(Body.GROUP), "still discoverable")
	assert_false(body.found)
	assert_eq(_bodies().size(), 1, "the dead specialist is not a body")


func test_dead_user_cannot_use_ability() -> void:
	var g := _guard(Vector3(1, 0, 0))
	await wait_physics_frames(2)
	user.take_damage(100)
	var knife: Ability = user.abilities["knife"]
	assert_false(knife.can_use(user, g))
	knife.use(user, g)
	assert_true(g.alive)


func test_body_round_trips_state() -> void:
	var body := _body_at(Vector3(2, 0, 3))
	body.found = true
	var d := JSON.parse_string(JSON.stringify(body.save_state())) as Dictionary
	var copy := _body_at(Vector3.ZERO)
	copy.load_state(d)
	assert_eq(copy.global_position, Vector3(2, 0, 3))
	assert_true(copy.found)
	assert_eq(d["carrier"], "")
	user.global_position = Vector3(2, 0, 3)
	(user.abilities["carry"] as Ability).use(user, body)
	assert_eq(body.save_state()["carrier"], String(user.name))


func test_dynamiter_has_two_charges() -> void:
	var charge: Ability = user.abilities["charge"]
	assert_eq(charge.ammo, 2)
	charge.use(user, null)
	charge.use(user, null)
	assert_eq(get_tree().get_nodes_in_group(PlantedCharge.GROUP).size(), 2)
	assert_false(charge.can_use(user, null), "a third plant is refused")
	charge.use(user, null)
	assert_eq(get_tree().get_nodes_in_group(PlantedCharge.GROUP).size(), 2)
	var d := JSON.parse_string(JSON.stringify(charge.save_state())) as Dictionary
	var copy := AbilityKit.create("charge")
	copy.load_state(d)
	assert_eq(copy.ammo, 0)


func test_weapons_refuse_a_specialist_target() -> void:
	user.grant_abilities(PackedStringArray(["knife", "rifle", "pistol"]))
	var friend := _spawn_specialist(PackedStringArray(), Vector3(1, 0, 0))
	await wait_physics_frames(2)
	for id in ["knife", "rifle", "pistol"]:
		var a: Ability = user.abilities[id]
		var before := a.ammo
		assert_false(a.can_use(user, friend), id)
		a.use(user, friend)
		assert_eq(a.ammo, before, id)
	assert_true(friend.alive)
	assert_eq(friend.hp, 100)
	assert_eq(noises.size(), 0)


func test_marksman_scene_has_exactly_rifle_and_pistol() -> void:
	var s := load("res://scenes/units/marksman.tscn").instantiate() as Specialist
	add_child_autofree(s)
	assert_eq(s.abilities.keys().size(), 2)
	assert_true(s.has_ability("rifle"))
	assert_true(s.has_ability("pistol"))
	assert_eq(s.stats.resource_path, "res://resources/marksman.tres")


# --- Using a weapon is something others can see: the unit turns to its target and says so ---

func _acts(unit: Unit) -> Array:
	var seen: Array = []
	unit.acted.connect(func(what: StringName, at: Vector3) -> void: seen.append([what, at]))
	return seen


func test_a_shot_turns_the_shooter_to_the_target_and_announces_it() -> void:
	var marksman := _spawn_specialist(PackedStringArray(["rifle", "pistol"]), Vector3(20, 0, 0))
	marksman.rotation.y = 1.0
	var guard := _guard(Vector3(20, 0, -12))
	var at := guard.global_position
	await wait_physics_frames(2)
	var seen := _acts(marksman)
	marksman.abilities["rifle"].use(marksman, guard)
	assert_eq(seen, [[&"rifle", at]])
	assert_almost_eq((-marksman.global_basis.z).normalized(), Vector3(0, 0, -1), Vector3.ONE * 0.001, "facing the guard")
	assert_false(guard.alive)


func test_a_pistol_shot_and_a_knife_announce_themselves_too() -> void:
	var guard := _guard(Vector3(1.2, 0, 0))
	var at := guard.global_position
	await wait_physics_frames(2)
	var seen := _acts(user)
	user.abilities["pistol"].use(user, guard)
	assert_eq(seen, [[&"pistol", at]])
	assert_true(guard.alive, "a pistol takes two shots")
	user.abilities["knife"].use(user, guard)
	assert_eq(seen.size(), 2)
	assert_eq(seen[1], [&"knife", at])
	assert_almost_eq((-user.global_basis.z).normalized(), Vector3(1, 0, 0), Vector3.ONE * 0.001)


func test_a_refused_shot_announces_nothing_and_turns_nobody() -> void:
	var guard := _guard(Vector3(0, 0, -10))
	_wall(Vector3(0, 1.5, -5), Vector3(6, 3, 0.5))
	await wait_physics_frames(2)
	user.rotation.y = 0.7
	var seen := _acts(user)
	user.abilities["pistol"].use(user, guard)
	assert_eq(seen, [])
	assert_almost_eq(user.rotation.y, 0.7, 0.0001)


func test_a_guard_firing_announces_its_shot() -> void:
	var guard := _guard(Vector3(0, 0, 0))
	user.global_position = Vector3(0, 0, -6)
	await wait_physics_frames(2)
	var seen := _acts(guard)
	guard.brain.on_alarm(user.global_position)
	for i in 40:
		guard.advance(guard.tuning.vision_interval)
	assert_gt(seen.size(), 0, "it fired within 4 s of the alarm")
	if seen.size() > 0:
		assert_eq(seen[0][0], &"rifle")
		assert_almost_eq(seen[0][1] as Vector3, user.global_position, Vector3.ONE * 0.01)
