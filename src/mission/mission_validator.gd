class_name MissionValidator
extends RefCounted
## Checks mission data on load. An empty result means the mission is valid.

const SPECIALISTS_REQUIRED := 2
const GUARDS_REQUIRED := 3
const REACH_TOLERANCE := 1.0


static func validate(mission: Mission) -> PackedStringArray:
	var errors := PackedStringArray()
	var specialists := mission.specialist_spawns()
	if specialists.size() < SPECIALISTS_REQUIRED:
		errors.append("mission needs %d specialist spawns, has %d" % [SPECIALISTS_REQUIRED, specialists.size()])
	var guards := mission.guard_spawns()
	if guards.size() < GUARDS_REQUIRED:
		errors.append("mission needs %d guard spawns, has %d" % [GUARDS_REQUIRED, guards.size()])
	for route in mission.patrol_routes():
		if route.curve == null or route.curve.point_count < 2:
			errors.append("route %s needs at least 2 points" % route.name)
	var target := mission.bridge_target()
	var extraction := mission.extraction()
	if target == null:
		errors.append("mission has no bridge target")
	if extraction == null:
		errors.append("mission has no extraction area")
	if specialists.is_empty():
		return errors
	var map := mission.nav_map()
	var from := specialists[0].global_position
	for spawn in specialists:
		if not _reaches(map, from, spawn.global_position):
			errors.append("specialist spawn %s is not connected to the others" % spawn.name)
	if target and not _reaches(map, from, target.global_position):
		errors.append("bridge target is unreachable from the specialist spawn")
	if extraction and not _reaches(map, from, extraction.global_position):
		errors.append("extraction is unreachable from the specialist spawn")
	return errors


static func _reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	if not map.is_valid():
		return false
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		return false
	# On the ground plane: an objective's node may sit above the floor, as the extraction area does.
	var end := path[path.size() - 1]
	return Vector2(end.x - to.x, end.z - to.z).length() <= REACH_TOLERANCE
