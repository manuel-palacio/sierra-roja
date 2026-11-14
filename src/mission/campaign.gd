class_name Campaign
extends RefCounted
## Which missions have been won, and so which are open: the first always, each other once every
## one before it in Missions.LIST is won. In the browser the wins are kept in local storage, so
## they outlive the page; elsewhere they last as long as the game runs.

const STORAGE_KEY := "sierra-roja-campaign"
const SCORES_KEY := "sierra-roja-scores"

static var _won: Dictionary = {}  # mission id -> true
static var _read := false
static var _best: Dictionary = {}  # mission id -> MissionScore


static func is_open(index: int) -> bool:
	if index < 0 or index >= Missions.LIST.size():
		return false
	# Every mission before it has to be won: one added to the middle of the list shuts what
	# comes after it until it is, though wins already made are kept.
	for earlier in index:
		if not is_won(Missions.id_at(earlier)):
			return false
	return true


static func is_won(id: String) -> bool:
	_read_storage()
	return _won.has(id)


static func mark_won(id: String) -> void:
	_read_storage()
	if Missions.index_of(id) < 0 or _won.has(id):
		return
	_won[id] = true
	_write_storage()


## The best win of a mission so far, or null.
static func best(id: String) -> MissionScore:
	_read_storage()
	return _best.get(id)


## Keeps a win's score when it beats the best so far. True when it did.
static func record(id: String, score: MissionScore) -> bool:
	_read_storage()
	if Missions.index_of(id) < 0 or score == null or not score.beats(_best.get(id)):
		return false
	_best[id] = MissionScore.from_dict(score.to_dict())
	_write_storage()
	return true


## Forgets every win and score, in storage too.
static func reset() -> void:
	_read = true
	_won.clear()
	_best.clear()
	_write_storage()


## Takes the best scores from stored text: a JSON object of mission id -> score. Anything else,
## and anything that is not a mission or a score, counts for nothing.
static func load_scores_from(text: String) -> void:
	_best.clear()
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Dictionary:
		return
	for id: Variant in json.data:
		var score := MissionScore.from_dict(json.data[id])
		if id is String and Missions.index_of(id) >= 0 and score != null:
			_best[id] = score


static func stored_scores() -> String:
	var out := {}
	for id in _best:
		out[id] = (_best[id] as MissionScore).to_dict()
	return JSON.stringify(out)


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
		load_scores_from(str(JavaScriptBridge.eval(
				"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % SCORES_KEY, true)))


static func _write_storage() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s', %s)}catch(e){}})()"
				% [STORAGE_KEY, JSON.stringify(stored_text())], true)
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s', %s)}catch(e){}})()"
				% [SCORES_KEY, JSON.stringify(stored_scores())], true)
