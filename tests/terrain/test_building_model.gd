extends GutTest
## A whole plaster building that is not gone into is drawn from its Blender model where there is
## one for its size, and is as solid as the one made of plain shapes.


func _building(size: Vector3, roof: float, storeys := 1) -> Building:
	var b := Building.new()
	b.size = size
	b.roof_height = roof
	b.storeys = storeys
	add_child_autofree(b)
	b.build(func(_x: float, _z: float) -> float: return 0.0)
	return b


func test_the_model_is_named_for_the_measures_in_decimetres() -> void:
	assert_eq(Building.model_path(Vector3(6.5, 5.4, 5), 1.5, 2, false), "res://assets/buildings/plaster-65x54x50-r15-s2.glb")
	assert_eq(Building.model_path(Vector3(4, 2.8, 3.4), 1.2, 1, true), "res://assets/buildings/plaster-40x28x34-r12-s1-snow.glb")


func test_a_building_with_a_model_is_drawn_from_it_and_is_solid() -> void:
	var b := _building(Vector3(9, 3, 5), 1.4)
	assert_not_null(b.get_node_or_null("Model"))
	assert_null(b.get_node_or_null("Roof"), "no roof of plain shapes as well")
	var shapes := b.find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 1)
	assert_eq(((shapes[0] as CollisionShape3D).shape as BoxShape3D).size, Vector3(9, 3 + Building.SINK, 5))
	assert_not_null(b.get_node_or_null("Smoke"))


func test_a_size_with_no_model_and_a_house_gone_into_are_built_of_plain_shapes() -> void:
	var odd := _building(Vector3(5.1, 3, 4.3), 1.4)
	assert_null(odd.get_node_or_null("Model"))
	assert_not_null(odd.get_node_or_null("Roof"))
	var entered := Building.new()
	entered.size = Vector3(9, 3, 5)
	entered.roof_height = 1.4
	entered.enterable = true
	add_child_autofree(entered)
	entered.build(func(_x: float, _z: float) -> float: return 0.0)
	assert_null(entered.get_node_or_null("Model"))


func test_every_plaster_house_the_missions_stand_whole_has_its_model() -> void:
	var found := 0
	for entry in Missions.LIST:
		var mission: Node = (load(entry["path"]) as PackedScene).instantiate()
		for node in mission.find_children("*", "StaticBody3D", true, false):
			var b := node as Building
			if b == null or b.enterable or b.ruin or b.style != &"plaster" or b.roof_height <= 0.0 or b.size.x < 3.0:
				continue
			found += 1
			assert_true(ResourceLoader.exists(Building.model_path(b.size, b.roof_height, b.storeys, b.snowy)),
					"%s in %s has no model: run tools/make_buildings.py" % [b.name, entry["id"]])
		mission.free()
	assert_gt(found, 4)
