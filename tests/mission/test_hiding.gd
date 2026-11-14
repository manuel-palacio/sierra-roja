extends GutTest
## Hiding places: a body left in one is never found, a specialist in one is not seen and can do
## nothing until they come out, and both survive a save.

var place: HidingPlace
var dyn: Specialist


func before_each() -> void:
	var prop := SettlementProp.new()
	prop.kind = &"haystack"
	add_child_autofree(prop)
	prop.stand(func(_x: float, _z: float) -> float: return 0.0)
	place = prop.get_node("HidingPlace") as HidingPlace
	dyn = load("res://scenes/units/specialist.tscn").instantiate() as Specialist
	add_child_autofree(dyn)
	dyn.global_position = Vector3(2.0, 0, 0)


func after_each() -> void:
	for b in get_tree().get_nodes_in_group(Body.GROUP):
		b.free()


func _guard(pos: Vector3) -> Guard:
	var g := load("res://scenes/units/guard.tscn").instantiate() as Guard
	add_child_autofree(g)
	g.global_position = pos
	g.set_physics_process(false)
	return g


func _body(pos: Vector3) -> Body:
	var b := load("res://scenes/units/body.tscn").instantiate() as Body
	add_child(b)
	b.global_position = pos
	return b


func test_haystacks_and_trucks_are_hiding_places_and_a_well_is_not() -> void:
	assert_not_null(place)
	var well := SettlementProp.new()
	well.kind = &"well"
	add_child_autofree(well)
	well.stand(func(_x: float, _z: float) -> float: return 0.0)
	assert_null(well.get_node_or_null("HidingPlace"))
	var truck := SettlementProp.new()
	truck.kind = &"truck"
	add_child_autofree(truck)
	truck.global_position = Vector3(30, 0, 0)
	truck.stand(func(_x: float, _z: float) -> float: return 0.0)
	dyn.global_position = Vector3(30, 0, 3.4)
	assert_true((truck.get_node("HidingPlace") as HidingPlace).can_interact(dyn), "from the tail of the truck too")


func test_a_hidden_specialist_is_not_seen_and_comes_out_on_f_or_a_move() -> void:
	var guard := _guard(Vector3(2.0, 0, 5.0))
	guard.look_at(Vector3(2.0, 0, 0), Vector3.UP)
	assert_ne(guard._strongest_target()["zone"], Vision.Zone.NONE, "in plain view to begin with")
	place.interact(dyn)
	assert_true(dyn.hidden)
	assert_eq(place.occupant(), dyn)
	assert_false((dyn.get_node("Model") as Node3D).visible)
	assert_eq(guard._strongest_target()["zone"], Vision.Zone.NONE)
	assert_false((dyn.abilities["pistol"] as Ability).can_use(dyn, guard), "nothing can be done from in there")
	place.interact(dyn)
	assert_false(dyn.hidden, "F again comes out")
	place.interact(dyn)
	dyn.move_to(Vector3(5, 0, 0))
	assert_false(dyn.hidden, "and so does an order to move")
	assert_true((dyn.get_node("Model") as Node3D).visible)


func test_nobody_gets_in_while_a_guard_is_looking() -> void:
	var guard := _guard(Vector3(20, 0, 20))
	guard.brain.on_alarm(Vector3.ZERO)
	place.interact(dyn)
	assert_false(dyn.hidden)
	assert_eq(place.prompt, HidingPlace.WATCHED_TEXT)


func test_a_body_left_inside_is_never_found_nor_lifted_again() -> void:
	var body := _body(dyn.global_position)
	dyn.pick_up(body)
	place.interact(dyn)
	assert_null(dyn.carrying)
	assert_true(body.hidden)
	assert_false(body.visible)
	assert_eq(place.body(), body)
	assert_false(dyn.hidden, "the body goes in, not the carrier")
	var guard := _guard(Vector3(0, 0, 3.0))
	guard.look_at(Vector3.ZERO, Vector3.UP)
	assert_null(guard._find_body())
	assert_false(body.found)
	assert_false((dyn.abilities["carry"] as Ability).can_use(dyn, body))
	var second := _body(dyn.global_position)
	dyn.pick_up(second)
	place.interact(dyn)
	assert_eq(dyn.carrying, second, "it holds one body")
	assert_eq(place.prompt, HidingPlace.BODY_FULL_TEXT)


func test_hiding_survives_a_save() -> void:
	place.interact(dyn)
	var saved := dyn.save_state()
	dyn.hidden = false
	dyn.load_state(saved)
	assert_true(dyn.hidden)
	var body := _body(Vector3.ZERO)
	body.hidden = true
	var kept := body.save_state()
	body.hidden = false
	body.load_state(kept)
	assert_true(body.hidden)
