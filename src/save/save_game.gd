extends Node
## Autoload. Quick save and load: one JSON file at user://quicksave.json, which on the web is the
## browser's IndexedDB. A file is checked whole by SaveSchema before anything live is touched, so
## a bad save changes nothing. Mission gathers and restores the state itself.
##
## On the web the file reaches IndexedDB some time after it closes: Godot syncs on a later frame
## and has no way to wait for it, and a page reload before that finishes loses the file. So each
## save is also put in localStorage, which is synchronous, and a load prefers that copy.

signal message(text: String)
## The save can't be used; whoever shows messages offers a restart.
signal restart_offered()

const VERSION := 2
const SAVE_PATH := "user://quicksave.json"
const BAD_SAVE_TEXT := "This save can't be loaded. Restart the mission?"

## Replaceable so tests don't touch a real save.
var path := SAVE_PATH


func quick_save(mission: Mission) -> Error:
	var data := mission.save_state()
	data["version"] = VERSION
	var text := JSON.stringify(data, "\t", false, true)
	var err := _write(text)
	if err == OK:
		_write_mirror(text)
	if err != OK:
		message.emit("Couldn't save the game")
		return err
	message.emit("Game saved")
	return OK


func quick_load(mission: Mission) -> Error:
	var text: Variant = _read_mirror()
	if text == null and FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text == null:
		message.emit("No save found")
		return ERR_FILE_NOT_FOUND
	var json := JSON.new()
	# JSON.parse rather than parse_string: a corrupt file must not log an engine error.
	if json.parse(text) != OK \
			or not SaveSchema.is_valid(json.data, VERSION, mission):
		message.emit(BAD_SAVE_TEXT)
		restart_offered.emit()
		return ERR_FILE_CORRUPT
	mission.load_state(json.data)
	message.emit("Game loaded")
	return OK


## Writes beside the save, then swaps it in, so a failed write leaves the old save whole.
func _write(text: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	var err := f.get_error()
	f.close()
	if err != OK:
		return err
	return DirAccess.rename_absolute(tmp, path)


## A failed write must not leave an older save to win over the file, so it clears the key.
func _write_mirror(text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			try { localStorage.setItem(%s, %s); }
			catch (e) { try { localStorage.removeItem(%s); } catch (e2) {} }
		""" % [JSON.stringify(path), JSON.stringify(text), JSON.stringify(path)], true)


## The saved text, or null off the web and when there is none.
func _read_mirror() -> Variant:
	if not OS.has_feature("web"):
		return null
	var js := "(function () { try { return localStorage.getItem(%s); } catch (e) { return null; } })()"
	return JavaScriptBridge.eval(js % JSON.stringify(path), true)
