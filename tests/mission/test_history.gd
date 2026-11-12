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
	assert_eq(History.before("powder_store"), "")
	assert_eq(History.before("nowhere"), "")
	assert_eq(History.sources("nowhere").size(), 0)


func test_no_day_is_given_where_the_sources_disagree() -> void:
	# The Segovia offensive opened on 30 or 31 May, by the source.
	assert_false(History.before("guadarrama").contains("30 May"))
	assert_false(String(Missions.LIST[Missions.index_of("guadarrama")]["date"]).contains("30"))
	assert_string_contains(History.before("guadarrama"), "May 1937")
