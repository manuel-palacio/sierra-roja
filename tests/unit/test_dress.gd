extends GutTest
## What a mission dresses its units in: by the kit each scene gives its unit.

const BASES: Array[StringName] = [&"guard", &"dynamiter", &"marksman", &"prisoner"]


func test_no_dress_changes_nothing() -> void:
	for base in BASES:
		assert_eq(Dress.kit(&"", base), base)
		assert_null(Dress.uniform(&"", base, null))


func test_spain_in_winter_puts_capes_on_and_keeps_the_uniforms() -> void:
	assert_eq(Dress.kit(&"spain_winter", &"guard"), &"guard_winter")
	assert_eq(Dress.kit(&"spain_winter", &"dynamiter"), &"dynamiter_winter")
	assert_eq(Dress.kit(&"spain_winter", &"marksman"), &"marksman_winter")
	assert_eq(Dress.kit(&"spain_winter", &"prisoner"), &"prisoner")
	var own := load("res://assets/characters/soldier/uniform-guard.png") as Texture2D
	assert_eq(Dress.uniform(&"spain_winter", &"guard", own), own)


func test_russia_dresses_guards_in_blue_and_the_pair_in_white() -> void:
	assert_eq(Dress.kit(&"russia", &"guard"), &"guard_blue")
	assert_eq(Dress.kit(&"russia", &"dynamiter"), &"dynamiter_russia")
	assert_eq(Dress.kit(&"russia", &"marksman"), &"marksman_russia")
	assert_true(Dress.uniform(&"russia", &"guard", null).resource_path.ends_with("uniform-guard_blue.png"))
	assert_true(Dress.uniform(&"russia", &"dynamiter", null).resource_path.ends_with("uniform-dynamiter_russia.png"))
	assert_true(Dress.uniform(&"russia", &"marksman", null).resource_path.ends_with("uniform-marksman_russia.png"))


func test_every_dressed_kit_exists() -> void:
	for dress in [&"spain_winter", &"russia"]:
		for base in BASES:
			var kit := Dress.kit(dress, base)
			assert_true(SoldierGear.KITS.has(kit), "%s in %s" % [kit, dress])
			assert_gt(SoldierGear.pieces(kit).size(), SoldierGear.FACE.size() - 1)


func test_an_unknown_dress_or_kit_falls_back() -> void:
	assert_eq(Dress.kit(&"tropics", &"guard"), &"guard")
	assert_eq(Dress.kit(&"russia", &"cook"), &"cook")
	var own := load("res://assets/characters/soldier/uniform-guard.png") as Texture2D
	assert_eq(Dress.uniform(&"tropics", &"guard", own), own)
	assert_eq(Dress.uniform(&"russia", &"cook", own), own)


func test_dressed_kits_keep_the_weapons_of_the_kit_they_come_from() -> void:
	for pair in [[&"guard", &"guard_winter"], [&"guard", &"guard_blue"], [&"dynamiter", &"dynamiter_winter"],
			[&"dynamiter", &"dynamiter_russia"], [&"marksman", &"marksman_winter"], [&"marksman", &"marksman_russia"]]:
		var held := func(kit: StringName) -> Array:
			var out := []
			for piece: Dictionary in SoldierGear.KITS[kit]:
				if piece.has("held"):
					out.append([piece["held"], piece["when"]])
			return out
		assert_eq(held.call(pair[1]), held.call(pair[0]), String(pair[1]))


func test_the_arm_shield_is_red_yellow_red_and_nothing_else_is_drawn_on_it() -> void:
	var on_sleeve := []
	for piece: Dictionary in SoldierGear.KITS[&"guard_blue"]:
		if piece.get("bone", "") == "DEF-upper_arm.R":
			on_sleeve.append(piece)
	assert_eq(on_sleeve.size(), 3, "three stripes and nothing more")
	# From the shoulder down the arm.
	on_sleeve.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"].x > b["at"].x)
	var colours := on_sleeve.map(func(p: Dictionary) -> Color: return p["color"])
	assert_gt(colours[0].r, 0.6); assert_lt(colours[0].g, 0.3)
	assert_gt(colours[1].r, 0.8); assert_gt(colours[1].g, 0.6); assert_lt(colours[1].b, 0.3)
	assert_eq(colours[2], colours[0])


func test_the_blue_division_guard_wears_field_grey_not_khaki() -> void:
	var dome: Dictionary = SoldierGear.KITS[&"guard_blue"][0]
	assert_eq(dome["bone"], "DEF-head")
	var c: Color = dome["color"]
	assert_almost_eq(c.r, c.b, 0.08, "a grey, between green and blue")
