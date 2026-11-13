extends GutTest
## Generated trees: a trunk, a dark core and a crown of leaf sprites.


func test_each_kind_comes_in_a_few_shared_variants() -> void:
	for kind in TreeBuilder.KINDS:
		var meshes := TreeBuilder.variants(kind)
		assert_eq(meshes.size(), TreeBuilder.VARIANTS, String(kind))
		assert_same(TreeBuilder.variants(kind)[0], meshes[0], "made once and shared")
	assert_eq(TreeBuilder.variants(&"palm").size(), 0, "no such kind, no meshes")


func test_a_tree_is_a_trunk_a_core_and_a_crown_of_leaf_sprites() -> void:
	var oak := TreeBuilder.variants(&"oak")[0]
	assert_eq(oak.get_surface_count(), 3)
	var leaves := oak.surface_get_material(2) as StandardMaterial3D
	assert_eq(leaves.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "cut out, not blended: it sorts and casts shadows")
	assert_eq(leaves.cull_mode, BaseMaterial3D.CULL_DISABLED, "seen from both sides")
	assert_not_null(leaves.albedo_texture)
	assert_not_null((oak.surface_get_material(0) as StandardMaterial3D).albedo_texture, "bark on the trunk")
	var bush := TreeBuilder.variants(&"bush")[0]
	assert_eq(bush.get_surface_count(), 2, "a bush has no trunk")


func test_trees_stand_on_the_ground_at_about_their_height() -> void:
	for kind in [&"pine", &"oak", &"olive", &"sapling", &"bush"]:
		var shape: Dictionary = TreeBuilder.KINDS[kind]
		for mesh in TreeBuilder.variants(kind):
			var box := mesh.get_aabb()
			assert_lt(box.position.y, 0.2, "%s reaches the ground" % kind)
			assert_between(box.end.y, float(shape["height"]) * 0.75, float(shape["height"]) * 1.45, "%s height" % kind)
			assert_lt(absf(box.get_center().x), 1.0, "%s stands over its own foot" % kind)


func test_pines_are_taller_and_narrower_than_oaks() -> void:
	var pine := TreeBuilder.variants(&"pine")[0].get_aabb()
	var oak := TreeBuilder.variants(&"oak")[0].get_aabb()
	assert_gt(pine.size.y, oak.size.y)
	assert_gt(oak.size.x / oak.size.y, pine.size.x / pine.size.y)


func test_variants_differ() -> void:
	var a := TreeBuilder.variants(&"oak")[0].get_aabb()
	var b := TreeBuilder.variants(&"oak")[1].get_aabb()
	assert_ne(a, b)


# --- Winter ---

func test_winter_kinds_build_three_variants_each() -> void:
	for kind in [&"snow_pine", &"birch", &"bare_bush"]:
		var meshes := TreeBuilder.variants(kind)
		assert_eq(meshes.size(), 3, String(kind))
		for mesh in meshes:
			assert_gt(mesh.get_surface_count(), 0, String(kind))
			assert_gt(mesh.get_aabb().size.y, 0.5, String(kind))


func test_a_birch_has_no_leaf_surface() -> void:
	var birch := TreeBuilder.variants(&"birch")[0]
	for i in birch.get_surface_count():
		var material := birch.surface_get_material(i) as StandardMaterial3D
		assert_ne(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "no leaf sprites on a bare tree")
	assert_eq(birch.get_surface_count(), 2, "a white trunk and its bare branches")
	assert_gt((birch.surface_get_material(0) as StandardMaterial3D).albedo_color.get_luminance(), 0.7, "the trunk is white")


func test_a_snow_pine_is_a_pine_gone_pale() -> void:
	var pine := TreeBuilder.variants(&"pine")[0]
	var snowy := TreeBuilder.variants(&"snow_pine")[0]
	assert_eq(snowy.get_surface_count(), pine.get_surface_count())
	assert_true(pine.surface_get_material(2) is StandardMaterial3D)
	var crown := snowy.surface_get_material(2) as ShaderMaterial
	assert_not_null(crown, "its boughs are drawn with snow lying on them")
	assert_gt(float(crown.get_shader_parameter("snow")), 0.5)
	assert_almost_eq(snowy.get_aabb().size.y, pine.get_aabb().size.y, 2.0, "the same tree underneath")
