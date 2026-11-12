class_name Missions
extends RefCounted
## The missions there are, in the order they are played, and which one is being played. The
## choice outlives a scene reload, which is how the game moves from one mission to another.
## A page address with ?mission=<id> starts on that mission.

const LIST: Array[Dictionary] = [
	{ "id": "bridge", "name": "The bridge", "path": "res://scenes/missions/bridge.tscn" },
	{ "id": "powder_store", "name": "The powder store", "path": "res://scenes/missions/powder_store.tscn" },
	{ "id": "bridge_night", "name": "The bridge by night", "path": "res://scenes/missions/bridge_night.tscn" },
	{ "id": "powder_store_night", "name": "The powder store by night", "path": "res://scenes/missions/powder_store_night.tscn" },
]

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


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


static func _read_address() -> void:
	if _address_read:
		return
	_address_read = true
	if OS.has_feature("web"):
		var asked := index_of(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mission')", true)))
		if asked >= 0:
			current = asked
