class_name MissionValidator
extends RefCounted
## Checks mission data on load. An empty result means the mission is valid.

const SPECIALISTS_REQUIRED := 2
const GUARDS_REQUIRED := 3
const REACH_TOLERANCE := 1.0
## A spawn or route point may be this far from the navmesh on the ground plane, and this far
## above or below it.
const GROUND_TOLERANCE := 1.0
const HEIGHT_TOLERANCE := 1.0


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
	var extraction := mission.extraction()
	var objectives := mission.objectives()
	if objectives.is_empty():
		errors.append("mission has no objectives")
	if extraction == null:
		errors.append("mission has no extraction area")
	if specialists.is_empty():
		return errors
	var map := mission.nav_map()
	var from := specialists[0].global_position
	for spawn in specialists:
		if not reaches(map, from, spawn.global_position):
			errors.append("specialist spawn %s is not connected to the others" % spawn.name)
	for spawn in specialists:
		_check_point(map, spawn.global_position, "specialist spawn %s" % spawn.name, errors)
	for spawn in guards:
		_check_point(map, spawn.global_position, "guard spawn %s" % spawn.name, errors)
	for route in mission.patrol_routes():
		if route.curve == null:
			continue
		var points: Array[Vector3] = []
		var sound := true
		for i in route.curve.point_count:
			points.append(route.to_global(route.curve.get_point_position(i)))
			var before := errors.size()
			# Route points are authored on the ground plane and set down by the mission.
			_check_point(map, points[i], "route %s point %d" % [route.name, i], errors, false)
			sound = sound and errors.size() == before
		# Every leg of a beat has to be walkable, the one back to the start included.
		if sound and points.size() >= 2:
			var legs := points.size() if points.size() > 2 else 1
			for i in legs:
				if not reaches(map, points[i], points[(i + 1) % points.size()]):
					errors.append("route %s leg %d cannot be walked" % [route.name, i])
	for o in objectives:
		errors.append_array(o.validate(mission, map, from))
	if extraction and not reaches(map, from, extraction.global_position):
		errors.append("extraction is unreachable from the specialist spawn")
	return errors


## A point units stand on must be over walkable ground and at its height. Ground too steep to
## walk has no navmesh, so a point on it fails the first test.
static func _check_point(map: RID, pos: Vector3, what: String, errors: PackedStringArray,
		check_height := true) -> void:
	if not map.is_valid():
		errors.append("%s is not on walkable ground" % what)
		return
	var nearest := NavigationServer3D.map_get_closest_point(map, pos)
	if Vector2(nearest.x - pos.x, nearest.z - pos.z).length() > GROUND_TOLERANCE:
		# Its own height may be what puts the nearest ground far away: look straight down too.
		var below := NavigationServer3D.map_get_closest_point(map, Vector3(pos.x, nearest.y, pos.z))
		if Vector2(below.x - pos.x, below.z - pos.z).length() > GROUND_TOLERANCE:
			errors.append("%s is not on walkable ground" % what)
			return
		nearest = below
	if check_height and absf(nearest.y - pos.y) > HEIGHT_TOLERANCE:
		errors.append("%s is %.1f m off the ground" % [what, absf(nearest.y - pos.y)])


static func reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	if not map.is_valid():
		return false
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		return false
	# On the ground plane: an objective's node may sit above the floor, as the extraction area does.
	var end := path[path.size() - 1]
	return Vector2(end.x - to.x, end.z - to.z).length() <= REACH_TOLERANCE
