extends GutTest


func test_a_campfire_has_stones_flames_smoke_and_a_flickering_light() -> void:
	var fire := Campfire.new()
	add_child_autofree(fire)
	assert_gte(fire.find_children("*", "MeshInstance3D", true, false).size(), 2, "stones and logs")
	assert_true(fire.flames.emitting)
	assert_true(fire.smoke.emitting)
	assert_gt(fire.smoke.lifetime, fire.flames.lifetime, "smoke hangs longer than flame")
	var seen := {}
	for i in 40:
		fire._process(0.05)
		seen[snappedf(fire.light.light_energy, 0.01)] = true
		assert_between(fire.light.light_energy, Campfire.LIGHT_ENERGY * (1.0 - Campfire.FLICKER),
				Campfire.LIGHT_ENERGY * (1.0 + Campfire.FLICKER))
	assert_gt(seen.size(), 5, "the light keeps changing")
	assert_eq(fire.find_children("*", "CollisionShape3D", true, false).size(), 0, "nothing to walk into")
