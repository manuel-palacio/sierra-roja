class_name Missions
extends RefCounted
## The missions there are, in the order they are played (the order of their dates), and which one
## is being played. The
## choice outlives a scene reload, which is how the game moves from one mission to another.
## A page address with ?mission=<id> starts on that mission.

const LIST: Array[Dictionary] = [
	{ "id": "guadarrama", "name": "The bridge", "place": "Sierra de Guadarrama", "date": "30 May 1937", "path": "res://scenes/missions/bridge.tscn" },
	{ "id": "powder_store", "name": "The powder store", "place": "", "date": "", "path": "res://scenes/missions/powder_store.tscn" },
	{ "id": "bridge_night", "name": "The bridge by night", "place": "", "date": "", "path": "res://scenes/missions/bridge_night.tscn" },
	{ "id": "powder_store_night", "name": "The powder store by night", "place": "", "date": "", "path": "res://scenes/missions/powder_store_night.tscn" },
]
## Ids a mission used to go by, so that old addresses still open it.
const ALIASES := { "bridge": "guadarrama" }

## Index into LIST of the mission being played.
static var current := 0
static var _address_read := false


## The scene of the mission being played.
static func path() -> String:
	_read_address()
	return LIST[current]["path"]


static func has_next() -> bool:
	return current < LIST.size() - 1


static func choose(index: int) -> void:
	_address_read = true
	current = clampi(index, 0, LIST.size() - 1)


## Where a mission is in LIST, by its id or one it used to have; -1 when there is none.
static func index_of(id: String) -> int:
	id = ALIASES.get(id, id)
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


static func id_at(index: int) -> String:
	return LIST[index]["id"] if index >= 0 and index < LIST.size() else ""


static func _read_address() -> void:
	if _address_read:
		return
	_address_read = true
	if OS.has_feature("web"):
		var asked := index_of(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mission')", true)))
		if asked >= 0:
			current = asked
