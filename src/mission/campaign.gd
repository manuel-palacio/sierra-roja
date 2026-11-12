class_name Campaign
extends RefCounted
## Which missions have been won, and so which are open: the first always, each other once the
## one before it in Missions.LIST is won. In the browser the wins are kept in local storage, so
## they outlive the page; elsewhere they last as long as the game runs.

const STORAGE_KEY := "sierra-roja-campaign"

static var _won: Dictionary = {}  # mission id -> true
static var _read := false


static func is_open(index: int) -> bool:
	if index < 0 or index >= Missions.LIST.size():
		return false
	return index == 0 or is_won(Missions.id_at(index - 1))


static func is_won(id: String) -> bool:
	_read_storage()
	return _won.has(id)


static func mark_won(id: String) -> void:
	_read_storage()
	if Missions.index_of(id) < 0 or _won.has(id):
		return
	_won[id] = true
	_write_storage()


## Forgets every win, in storage too.
static func reset() -> void:
	_read = true
	_won.clear()
	_write_storage()


## Takes the wins from stored text: a JSON array of mission ids. Anything else, and any id that
## is not a mission, counts for nothing.
static func load_from(text: String) -> void:
	_read = true
	_won.clear()
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Array:
		return
	for id: Variant in json.data:
		if id is String and Missions.index_of(id) >= 0:
			_won[Missions.id_at(Missions.index_of(id))] = true


## The wins as load_from reads them.
static func stored_text() -> String:
	return JSON.stringify(_won.keys())


static func _read_storage() -> void:
	if _read:
		return
	_read = true
	if OS.has_feature("web"):
		# A browser may refuse storage altogether; that is the same as having none.
		load_from(str(JavaScriptBridge.eval(
				"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % STORAGE_KEY, true)))


static func _write_storage() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s', %s)}catch(e){}})()"
				% [STORAGE_KEY, JSON.stringify(stored_text())], true)
