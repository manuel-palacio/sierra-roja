class_name SaveSchema
extends RefCounted
## Decides whether parsed save data can be applied to a mission, without touching it. Everything
## load_state reads is checked here, types and ranges included, so load_state itself can't fail.


static func is_valid(d: Variant, version: int, mission: Mission) -> bool:
	if not d is Dictionary:
		return false
	if not _is_int(d.get("version")) or d["version"] != version:
		return false
	if not d.get("mission") is String or d["mission"] != mission.scene_file_path:
		return false
	for key in ["specialists", "prisoners", "guards", "bodies", "charges"]:
		if not d.get(key) is Array:
			return false
	if not d.get("rules") is Dictionary:
		return false
	return _specialists_ok(d["specialists"], mission) and _prisoners_ok(d["prisoners"], mission) \
			and _guards_ok(d["guards"], mission) \
			and _bodies_ok(d["bodies"], d["specialists"], d["guards"]) and _charges_ok(d["charges"]) \
			and _rules_ok(d["rules"], mission)


static func _specialists_ok(list: Array, mission: Mission) -> bool:
	var live := mission.specialists()
	if list.size() != live.size():
		return false
	var by_id := {}
	for s in live:
		by_id[String(s.name)] = s
	var seen := {}
	for e in list:
		if not _unit_ok(e) or not by_id.has(e["id"]) or seen.has(e["id"]):
			return false
		seen[e["id"]] = true
		var s: Specialist = by_id[e["id"]]
		if not _is_bool(e.get("can_run")) or e["hp"] > s.stats.max_hp or not e.get("abilities") is Dictionary:
			return false
		if e["abilities"].size() != s.abilities.size():
			return false
		for id in s.abilities:
			var a: Variant = e["abilities"].get(id)
			if not a is Dictionary or not _is_int(a.get("ammo")) or a["ammo"] < -1:
				return false
	return true


## One entry for each prisoner of the mission, each following nobody or one of its specialists.
static func _prisoners_ok(list: Array, mission: Mission) -> bool:
	var live := mission.prisoners()
	if list.size() != live.size():
		return false
	var ids := {}
	for held in live:
		ids[String(held.name)] = held
	var leaders := {"": true}
	for s in mission.specialists():
		leaders[String(s.name)] = true
	var seen := {}
	for e in list:
		if not _unit_ok(e) or not ids.has(e["id"]) or seen.has(e["id"]):
			return false
		seen[e["id"]] = true
		if not e.get("leader") is String or not leaders.has(e["leader"]) or e["hp"] > (ids[e["id"]] as Prisoner).stats.max_hp:
			return false
	return true


static func _guards_ok(list: Array, mission: Mission) -> bool:
	var seen := {}
	for e in list:
		if not _unit_ok(e) or not mission.has_guard_slot(e["id"]) or seen.has(e["id"]) or not e["alive"]:
			return false
		seen[e["id"]] = true
		if not _is_int(e.get("waypoint")) or e["waypoint"] < 0:
			return false
		var route_size := mission.guard_route(e["id"]).size()
		if e["waypoint"] >= maxi(route_size, 1):
			return false
		if not _is_num(e.get("fire_timer")) or not _is_num(e.get("vision_timer")):
			return false
		if e.get("alarm_dest") != null and not _is_vec3(e.get("alarm_dest")):
			return false
		if not _brain_ok(e.get("brain")):
			return false
	return true


static func _brain_ok(b: Variant) -> bool:
	if not b is Dictionary or not _is_enum(b.get("state"), GuardBrain.State.size()):
		return false
	for key in ["far_total", "no_sight", "wait"]:
		if not _is_num(b.get(key)):
			return false
	return _is_bool(b.get("alerted")) and _is_bool(b.get("arrived")) and _is_vec3(b.get("goal"))


static func _bodies_ok(list: Array, specialists: Array, guards: Array) -> bool:
	var carriers := {}
	for s in specialists:
		if s["alive"]:
			carriers[s["id"]] = false
	var guard_ids := {}
	for g in guards:
		guard_ids[g["id"]] = true
	for e in list:
		if not e is Dictionary or not e.get("id") is String or guard_ids.has(e["id"]):
			return false
		if not _is_vec3(e.get("pos")) or not _is_num(e.get("rot")) or not _is_bool(e.get("found")):
			return false
		var carrier: Variant = e.get("carrier")
		if not carrier is String:
			return false
		if carrier != "":
			if not carriers.has(carrier) or carriers[carrier]:
				return false
			carriers[carrier] = true
	return true


static func _charges_ok(list: Array) -> bool:
	for e in list:
		if not e is Dictionary or not e.get("id") is String:
			return false
		if not _is_vec3(e.get("pos")) or not _is_num(e.get("fuse_left")) or e["fuse_left"] < 0.0:
			return false
	return true


static func _rules_ok(r: Dictionary, mission: Mission) -> bool:
	if not _is_enum(r.get("result"), MissionRules.Result.size()):
		return false
	var objectives := mission.objectives()
	if not r.get("objectives") is Array or r["objectives"].size() != objectives.size():
		return false
	for i in objectives.size():
		if not objectives[i].state_ok(r["objectives"][i]):
			return false
	if not r.get("at_extraction") is Array:
		return false
	var ids := mission.specialists().map(func(s: Specialist) -> String: return String(s.name))
	ids.append_array(mission.prisoners().map(func(p: Prisoner) -> String: return String(p.name)))
	for id in r["at_extraction"]:
		if not ids.has(id):
			return false
	return true


## What every Unit.save_state holds.
static func _unit_ok(e: Variant) -> bool:
	if not e is Dictionary or not e.get("id") is String:
		return false
	if not _is_vec3(e.get("pos")) or not _is_vec3(e.get("target")):
		return false
	if not _is_num(e.get("rot")) or not _is_num(e.get("noise_timer")):
		return false
	if not _is_enum(e.get("stance"), Unit.Stance.size()) or not _is_int(e.get("hp")) or e["hp"] < 0:
		return false
	if not _is_bool(e.get("alive")) or e["alive"] != (e["hp"] > 0):
		return false
	return _is_bool(e.get("moving")) and _is_bool(e.get("running"))


static func _is_num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _is_int(v: Variant) -> bool:
	return _is_num(v) and float(v) == floorf(float(v))


static func _is_enum(v: Variant, size: int) -> bool:
	return _is_int(v) and v >= 0 and v < size


static func _is_bool(v: Variant) -> bool:
	return v is bool


static func _is_vec3(v: Variant) -> bool:
	if not v is Array or v.size() != 3:
		return false
	for n in v:
		if not _is_num(n):
			return false
	return true
