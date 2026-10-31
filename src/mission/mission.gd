class_name Mission
extends Node3D
## A mission map. Spawns, routes and objectives are plain nodes found by name, so a new
## mission is a new scene with no engine code. Expected children:
## SpecialistSpawns/ and GuardSpawns/ (Marker3D), Routes/ (Path3D), BridgeTarget (Marker3D),
## Extraction (Area3D) and Nav (NavigationRegion3D holding the walkable geometry).

## Ground-plane extent (x, z in metres) the camera may show.
@export var bounds_rect := Rect2(-40.0, -30.0, 80.0, 60.0)


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
	var region := _region()
	if region == null or region.navigation_mesh == null:
		return
	var data := NavigationMeshSourceGeometryData3D.new()
	_collect_faces(region, region, data)
	NavigationServer3D.bake_from_source_geometry_data(region.navigation_mesh, data)
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), region.navigation_mesh)
	NavigationServer3D.map_force_update(region.get_navigation_map())


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
