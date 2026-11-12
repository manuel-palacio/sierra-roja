extends GutTest
## Which missions are open: the first always, each other once the one before it is won.


func before_each() -> void:
	Campaign.reset()


func after_all() -> void:
	Campaign.reset()


func test_only_the_first_mission_is_open_at_first() -> void:
	assert_true(Campaign.is_open(0))
	assert_false(Campaign.is_open(1))


func test_winning_opens_the_next() -> void:
	Campaign.mark_won(Missions.id_at(0))
	assert_true(Campaign.is_won(Missions.id_at(0)))
	assert_true(Campaign.is_open(1))
	assert_false(Campaign.is_open(2))


func test_rubbish_in_storage_means_nothing_won() -> void:
	for text in ["", "{", "42", "{\"a\":1}", "[1, null, \"nowhere\"]"]:
		Campaign.load_from(text)
		assert_false(Campaign.is_open(1), text)
		assert_true(Campaign.is_open(0), text)


func test_stored_wins_are_read_back() -> void:
	Campaign.load_from("[\"guadarrama\"]")
	assert_true(Campaign.is_won("guadarrama"))
	assert_true(Campaign.is_open(1))


func test_what_is_stored_can_be_read_back() -> void:
	Campaign.mark_won("guadarrama")
	var text := Campaign.stored_text()
	Campaign.reset()
	Campaign.load_from(text)
	assert_true(Campaign.is_won("guadarrama"))


func test_an_index_off_the_list_is_not_open() -> void:
	assert_false(Campaign.is_open(-1))
	assert_false(Campaign.is_open(99))
