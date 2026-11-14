extends GutTest
## The game in Spanish: every text the player reads has its Spanish, and what is on the screen
## changes with the language.

const SCENE_TEXTS := "^(title|hud_text|done_text|marker_name|escort_text|carry_text|label|prompt) = \"(.*)\"$"

var _locale_before := ""


func before_each() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("es")


func after_each() -> void:
	TranslationServer.set_locale(_locale_before)


func _assert_spanish(text: String, where: String) -> void:
	assert_ne(tr(text), text, "%s has no Spanish: %s" % [where, text])


func test_the_missions_and_their_history_have_spanish() -> void:
	for entry in Missions.LIST:
		for key in ["name", "date"]:
			_assert_spanish(entry[key], entry["id"])
		_assert_spanish(History.before(entry["id"]), entry["id"])
		_assert_spanish(History.after(entry["id"]), entry["id"])
	assert_eq(tr("Sierra de Guadarrama"), "Sierra de Guadarrama", "a Spanish place keeps its name")
	assert_eq(tr("The Ebro"), "El Ebro")


func test_every_text_in_the_mission_scenes_has_spanish() -> void:
	var one := RegEx.create_from_string(SCENE_TEXTS)
	var quoted := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var found := 0
	for entry in Missions.LIST:
		for line in FileAccess.get_file_as_string(entry["path"]).split("\n"):
			if line.begins_with("briefing_lines = "):
				for m in quoted.search_all(line):
					_assert_spanish(m.get_string(1), entry["id"])
					found += 1
			var m := one.search(line)
			if m != null:
				_assert_spanish(m.get_string(2), entry["id"])
				found += 1
	assert_gt(found, 30, "the scenes were read")
	for line in Mission.new().briefing_lines:
		_assert_spanish(line, "the default briefing")


func test_the_controls_and_the_ability_names_have_spanish() -> void:
	for row in Briefing.CONTROLS:
		_assert_spanish(row[1], "controls")
	for id in Hud.LABELS:
		_assert_spanish(Hud.LABELS[id], "ability")


func test_texts_made_of_parts_come_out_in_spanish() -> void:
	var cut := CutObjective.new()
	autofree(cut)
	cut.hud_text = "Cut the telephone lines"
	assert_eq(cut.current_hud_text(), "Corta las líneas telefónicas: quedan 0")


func test_the_briefing_changes_language_where_it_stands() -> void:
	TranslationServer.set_locale("en")
	var briefing := Briefing.new()
	add_child_autofree(briefing)
	assert_eq(briefing.mission_buttons[0].text, "1  Sierra de Guadarrama, May 1937")
	assert_eq(briefing.language_button.text, "Español")
	briefing.language_button.pressed.emit()
	assert_eq(Language.current(), "es")
	assert_eq(briefing.mission_buttons[0].text, "1  Sierra de Guadarrama, Mayo de 1937")
	assert_eq(briefing.language_button.text, "English")
	briefing.language_button.pressed.emit()
	assert_eq(Language.current(), "en")
