extends GutTest
## The title: Start takes it down, keys stop at it, and Continue goes to the furthest open mission.


func before_each() -> void:
	Campaign.reset()
	TitleScreen.seen = false
	Missions.choose(0)


func after_each() -> void:
	Campaign.reset()
	TitleScreen.seen = false


func test_start_takes_the_title_down_once_and_it_is_not_wanted_again() -> void:
	var title := TitleScreen.new()
	add_child_autofree(title)
	watch_signals(title)
	assert_eq(title.title_label.text, "Sierra Roja")
	title.start_button.pressed.emit()
	title.begin()
	assert_signal_emit_count(title, "started", 1)
	assert_true(TitleScreen.seen)
	assert_false(TitleScreen.wanted())


func test_continue_is_offered_only_once_there_is_somewhere_further_to_go() -> void:
	var fresh := TitleScreen.new()
	add_child_autofree(fresh)
	assert_false(fresh.continue_button.visible)
	Campaign.mark_won("guadarrama")
	Campaign.mark_won("teruel")
	var later := TitleScreen.new()
	add_child_autofree(later)
	watch_signals(later)
	assert_true(later.continue_button.visible)
	later.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(later, "continue_chosen", [2])


func test_the_title_has_spanish() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	assert_ne(tr(TitleScreen.SUBTITLE), TitleScreen.SUBTITLE)
	assert_ne(tr("Continue"), "Continue")
	TranslationServer.set_locale(before)


func test_the_title_says_what_the_game_is_and_lists_the_missions_in_either_language() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var title := TitleScreen.new()
	add_child_autofree(title)
	var texts: Array = title.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	for line in TitleScreen.ABOUT:
		assert_has(texts, line)
	assert_eq(title.mission_labels.size(), Missions.LIST.size())
	assert_eq(title.mission_labels[5].text, "6  Krasny Bor, 9 February 1943")
	assert_eq(title.language_button.text, "Español")
	title.language_button.pressed.emit()
	assert_eq(title.mission_labels[5].text, "6  Krasny Bor, 9 de febrero de 1943")
	for line in TitleScreen.ABOUT + [TitleScreen.FOOT]:
		assert_ne(tr(line), line, "no Spanish: " + line)
	TranslationServer.set_locale(before)
