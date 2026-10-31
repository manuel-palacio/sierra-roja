class_name Mission
extends Node3D
## A mission map. Spawns, routes and objectives are plain nodes found by name, so a new
## mission is a new scene with no engine code. Expected children:
## SpecialistSpawns/ and GuardSpawns/ (Marker3D), Routes/ (Path3D), BridgeTarget (Marker3D),
## Extraction (Area3D) and Nav (NavigationRegion3D holding the walkable geometry).
## Guards/ holds the guard instances; each takes the spawn and route at its own index.
##
## For saves, a Unit's id is its node name. save_state/load_state gather and restore the whole
## mission; load_state trusts its input, which SaveSchema has already checked.

## The load has been applied. Anything holding on to game state should re-check it now.
signal state_loaded()

const GUARD_SCENE := "res://scenes/units/guard.tscn"

## Ground-plane extent (x, z in metres) the camera may show.
@export var bounds_rect := Rect2(-40.0, -30.0, 80.0, 60.0)

## Set by MissionRules.setup.
var rules: MissionRules
## Navmesh bakes so far, so a test can see that a stale one did not run.
var nav_bakes := 0

## Guard id -> route, kept for every guard the map starts with so a dead one can come back.
var _guard_routes: Dictionary = {}
## The deck while the bridge is down, out of the tree, for a load that wants it back.
var _intact_deck: CSGBox3D
## Only the newest deferred rebake runs.
var _rebake_request := 0


func _ready() -> void:
	var spawns := guard_spawns()
	var routes := patrol_routes()
	var list := guards()
	for i in list.size():
		if i < spawns.size():
			list[i].global_position = spawns[i].global_position
		var route := _route_points(routes[i]) if i < routes.size() else PackedVector3Array()
		list[i].set_route(route)
		_guard_routes[String(list[i].name)] = route


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_intact_deck):
		_intact_deck.free()


func specialists() -> Array[Specialist]:
	var out: Array[Specialist] = []
	for child in get_children():
		if child is Specialist:
			out.append(child)
	return out


func has_guard_slot(id: String) -> bool:
	return _guard_routes.has(id)


func guard_route(id: String) -> PackedVector3Array:
	return _guard_routes.get(id, PackedVector3Array())


func specialist_spawns() -> Array[Marker3D]:
	return _markers("SpecialistSpawns")


func guard_spawns() -> Array[Marker3D]:
	return _markers("GuardSpawns")


func patrol_routes() -> Array[Path3D]:
	var out: Array[Path3D] = []
	var holder := get_node_or_null("Routes")
	if holder:
		for child in holder.get_children():
			if child is Path3D:
				out.append(child)
	return out


func guards() -> Array[Guard]:
	var out: Array[Guard] = []
	var holder := get_node_or_null("Guards")
	if holder:
		for child in holder.get_children():
			if child is Guard:
				out.append(child)
	return out


func bridge_target() -> Marker3D:
	return get_node_or_null("BridgeTarget") as Marker3D


func extraction() -> Area3D:
	return get_node_or_null("Extraction") as Area3D


func nav_map() -> RID:
	var region := _region()
	return region.get_navigation_map() if region else RID()


## Bakes the navigation mesh on the main thread (the web build has no threads) and
## syncs the navigation map so path queries work straight away.
## The source geometry is fed in procedurally from the CSG collision faces. Letting
## NavigationRegion3D.bake_navigation_mesh parse CSG nodes goes through RenderingServer
## meshes, which Godot warns about (GPU readback) and which fails the GUT run.
func build_nav() -> void:
	if not rebake_nav():
		return
	for guard in guards():
		guard.set_nav_map(nav_map())
		guard.start_patrol()


## Rebakes without touching the guards, for a map that changes mid-mission.
func rebake_nav() -> bool:
	var region := _region()
	if region == null or region.navigation_mesh == null:
		return false
	nav_bakes += 1
	var data := NavigationMeshSourceGeometryData3D.new()
	_collect_faces(region, region, data)
	NavigationServer3D.bake_from_source_geometry_data(region.navigation_mesh, data)
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), region.navigation_mesh)
	NavigationServer3D.map_force_update(region.get_navigation_map())
	return true


## Spawns the Dynamiter and the Marksman at the two specialist spawns, on this mission's navmesh.
func spawn_specialists() -> Array[Specialist]:
	var out: Array[Specialist] = []
	var spawns := specialist_spawns()
	var scenes := ["res://scenes/units/specialist.tscn", "res://scenes/units/marksman.tscn"]
	for i in mini(spawns.size(), scenes.size()):
		var s := (load(scenes[i]) as PackedScene).instantiate() as Specialist
		add_child(s)
		s.global_position = spawns[i].global_position
		s.set_nav_map(nav_map())
		out.append(s)
	return out


## Swaps the intact deck for broken stubs reaching 3 m out from each bank, then rebakes the
## navmesh so nothing can path across the gorge. Safe to call twice.
func break_bridge() -> void:
	var region := _region()
	var deck := get_node_or_null("Nav/BridgeDeck")
	if region == null or deck == null:
		return
	region.remove_child(deck)
	_intact_deck = deck
	var stubs := Node3D.new()
	stubs.name = "BridgeBroken"
	region.add_child(stubs)
	var half: float = (deck as CSGBox3D).size.x / 2.0
	for sign in [-1.0, 1.0]:
		var stub := CSGBox3D.new()
		stub.use_collision = true
		stub.size = Vector3(3.0, 0.4, (deck as CSGBox3D).size.z)
		stub.material = (deck as CSGBox3D).material
		stubs.add_child(stub)
		stub.position = Vector3(deck.position.x + sign * (half - 1.5), deck.position.y, deck.position.z)
	_rebake_next_frame()


## Undoes break_bridge, for a load whose save has the bridge whole. Safe to call on a whole bridge.
func repair_bridge() -> void:
	var region := _region()
	if region == null or _intact_deck == null:
		return
	var stubs := region.get_node_or_null("BridgeBroken")
	if stubs != null:
		stubs.free()
	region.add_child(_intact_deck)
	_intact_deck = null
	_rebake_next_frame()


## JSON-safe snapshot of everything that changes in play, but for the save's version. Dead units
## and spent charges are left out, however recently they went.
func save_state() -> Dictionary:
	var charges: Array[Dictionary] = []
	for charge in _mine(PlantedCharge.GROUP):
		if not charge.is_queued_for_deletion():
			var d: Dictionary = charge.save_state()
			d["id"] = "charge_%d" % charges.size()
			charges.append(d)
	var bodies: Array[Dictionary] = []
	for body in _mine(Body.GROUP):
		bodies.append(body.save_state())
	var live_guards: Array[Dictionary] = []
	for guard in guards():
		if guard.alive:
			live_guards.append(guard.save_state())
	var specialist_states: Array[Dictionary] = []
	for s in specialists():
		specialist_states.append(s.save_state())
	return {
		"mission": scene_file_path,
		"specialists": specialist_states,
		"guards": live_guards,
		"bodies": bodies,
		"charges": charges,
		"rules": rules.save_state() if rules else {},
	}


## Puts the mission back as saved, in place, so everything already wired to it stays wired. Nodes
## to drop are freed at once rather than queued: a queued charge could still go off this frame,
## and a queued guard would still hold the name its replacement needs.
func load_state(d: Dictionary) -> void:
	var by_id := {}
	for s in specialists():
		by_id[String(s.name)] = s
	for e in d["specialists"]:
		by_id[e["id"]].load_state(e)
	for node in _mine(PlantedCharge.GROUP) + _mine(Body.GROUP):
		node.free()
	_load_guards(d["guards"])
	for e in d["bodies"]:
		var body := (load(Body.SCENE) as PackedScene).instantiate() as Body
		get_node("Guards").add_child(body)
		body.load_state(e)
		if e["carrier"] != "":
			by_id[e["carrier"]].pick_up(body)
	for e in d["charges"]:
		var charge := PlantedCharge.new()
		add_child(charge)
		charge.load_state(e)
	rules.load_state(d["rules"])
	state_loaded.emit()


func _load_guards(saved: Array) -> void:
	var wanted := {}
	for e in saved:
		wanted[e["id"]] = e
	for guard in guards():
		if not guard.alive or not wanted.has(String(guard.name)):
			guard.free()
	for id in wanted:
		var guard := get_node("Guards").get_node_or_null(NodePath(id)) as Guard
		if guard == null:
			guard = _respawn_guard(id)
		guard.load_state(wanted[id])


## A fresh guard joins the alarm sharing and the noise bus as it enters the tree, as any guard does.
func _respawn_guard(id: String) -> Guard:
	var guard := (load(GUARD_SCENE) as PackedScene).instantiate() as Guard
	guard.name = id
	get_node("Guards").add_child(guard)
	guard.set_route(guard_route(id))
	guard.set_nav_map(nav_map())
	return guard


## This mission's members of a group; nodes outside the mission are none of its business.
func _mine(group: String) -> Array[Node]:
	var out: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if is_ancestor_of(node):
			out.append(node)
	return out


## CSG builds its geometry on the next idle frame, so the rebake waits one frame (callers need not
## await it). A newer request, or leaving the tree, cancels an older one.
func _rebake_next_frame() -> void:
	_rebake_request += 1
	var request := _rebake_request
	await get_tree().process_frame
	if request == _rebake_request and is_inside_tree():
		rebake_nav()


func _route_points(route: Path3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in route.curve.point_count:
		points.append(route.to_global(route.curve.get_point_position(i)))
	return points


func _collect_faces(node: Node, region: NavigationRegion3D, data: NavigationMeshSourceGeometryData3D) -> void:
	for child in node.get_children():
		var csg := child as CSGShape3D
		if csg and csg.is_root_shape():
			var shape := csg.bake_collision_shape()
			if shape:
				var to_region := region.global_transform.affine_inverse() * csg.global_transform
				data.add_faces(shape.get_faces(), to_region)
		_collect_faces(child, region, data)


func _region() -> NavigationRegion3D:
	return get_node_or_null("Nav") as NavigationRegion3D


func _markers(holder_name: String) -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	var holder := get_node_or_null(holder_name)
	if holder:
		for child in holder.get_children():
			if child is Marker3D:
				out.append(child)
	return out
