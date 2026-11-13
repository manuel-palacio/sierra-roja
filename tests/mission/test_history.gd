extends GutTest
## The notes shown before and after a mission. What they may say is fixed by the design's table
## of sources; these tests hold the shape, not the history.


func test_every_note_has_an_ending_and_a_source() -> void:
	var with_notes := 0
	for entry: Dictionary in Missions.LIST:
		var id: String = entry["id"]
		if History.before(id) == "":
			assert_eq(History.after(id), "", id)
			continue
		with_notes += 1
		assert_ne(History.after(id), "", id)
		assert_gt(History.sources(id).size(), 0, id)
	assert_gt(with_notes, 0)


func test_the_bridge_is_owned_up_to_as_fiction() -> void:
	assert_string_contains(History.before("guadarrama"), "not history's")
	assert_string_contains(History.before("guadarrama"), "invented")


func test_a_mission_without_a_note_has_none() -> void:
	assert_eq(History.before("nowhere"), "")
	assert_eq(History.sources("nowhere").size(), 0)


func test_no_day_is_given_where_the_sources_disagree() -> void:
	# The Segovia offensive opened on 30 or 31 May, by the source.
	assert_false(History.before("guadarrama").contains("30 May"))
	assert_false(String(Missions.LIST[Missions.index_of("guadarrama")]["date"]).contains("30"))
	assert_string_contains(History.before("guadarrama"), "May 1937")


func test_teruel_has_its_notes() -> void:
	assert_string_contains(History.before("teruel"), "December 1937")
	assert_string_contains(History.before("teruel"), "invented")
	assert_string_contains(History.after("teruel"), "February 1938")
	assert_gt(History.sources("teruel").size(), 0)


func test_the_volkhov_note_owns_up_to_the_raid_being_invented() -> void:
	assert_string_contains(History.before("volkhov"), "invented")
	assert_false(History.before("volkhov").contains("fought on the Volkhov"), "no claim that exiles fought there")
	assert_string_contains(History.after("volkhov"), "August 1942")
	assert_eq(History.sources("volkhov").size(), 2)


func test_the_volkhov_is_dated_no_closer_than_its_source() -> void:
	assert_false(History.before("volkhov").contains("1941"), "the source gives no 1941 date for the Volkhov")
	assert_string_contains(History.before("volkhov"), "1942")
	assert_eq(Missions.LIST[Missions.index_of("volkhov")]["date"], "Early 1942")


func test_the_ebro_note_says_it_is_said() -> void:
	assert_string_contains(History.before("ebro"), "It is said")
	assert_string_contains(History.before("ebro"), "24 to 25 July 1938")
	assert_string_contains(History.after("ebro"), "16 November")
	assert_gt(History.sources("ebro").size(), 0)


func test_krasny_bor_ends_on_what_it_cost() -> void:
	assert_string_contains(History.before("krasny_bor"), "invented")
	assert_string_contains(History.after("krasny_bor"), "3,645")
	assert_string_contains(History.after("krasny_bor"), "a third")
	assert_gt(History.sources("krasny_bor").size(), 0)


func test_every_mission_now_has_its_history() -> void:
	for entry: Dictionary in Missions.LIST:
		assert_ne(History.before(entry["id"]), "", entry["id"])
		assert_ne(History.after(entry["id"]), "", entry["id"])
		assert_ne(entry["place"], "", entry["id"])
