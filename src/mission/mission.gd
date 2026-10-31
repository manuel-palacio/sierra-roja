class_name Mission
extends Node3D
## A mission map. Spawns, routes and objectives are plain nodes found by name, so a new
## mission is a new scene with no engine code. Expected children:
## SpecialistSpawns/ and GuardSpawns/ (Marker3D), Routes/ (Path3D), BridgeTarget (Marker3D),
## Extraction (Area3D) and Nav (NavigationRegion3D holding the walkable geometry).
## Guards/ holds the guard instances; each takes the spawn and route at its own index.

## Ground-plane extent (x, z in metres) the camera may show.
@export var bounds_rect := Rect2(-40.0, -30.0, 80.0, 60.0)


func _ready() -> void:
	var spawns := guard_spawns()
	var routes := patrol_routes()
	var list := guards()
	for i in list.size():
		if i < spawns.size():
			list[i].global_position = spawns[i].global_position
		if i < routes.size():
			list[i].set_route(_route_points(routes[i]))


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
## navmesh so nothing can path across the gorge. Safe to call twice. CSG builds its geometry
## on the next idle frame, so the rebake waits one frame (callers need not await it).
func break_bridge() -> void:
	var region := _region()
	var deck := get_node_or_null("Nav/BridgeDeck")
	if region == null or deck == null:
		return
	region.remove_child(deck)
	deck.queue_free()
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
	await get_tree().process_frame
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
