class_name Mission
extends Node3D
## A mission map. Spawns, routes and objectives are plain nodes found by name, so a new
## mission is a new scene with no engine code. Expected children:
## SpecialistSpawns/ and GuardSpawns/ (Marker3D), Routes/ (Path3D), Objectives/ (Objective),
## Extraction (Area3D) and Nav (NavigationRegion3D holding the walkable geometry).
## Guards/ holds the guard instances; each takes the spawn and route at its own index.
##
## For saves, a Unit's id is its node name. save_state/load_state gather and restore the whole
## mission; load_state trusts its input, which SaveSchema has already checked.

## The load has been applied. Anything holding on to game state should re-check it now.
signal state_loaded()
## The navmesh has just been baked again (the bridge broke, or was put back by a load).
signal nav_rebaked()

const GUARD_SCENE := "res://scenes/units/guard.tscn"
## The bake leaves its surface this many cells above the real ground.
const NAV_BAKE_LIFT_CELLS := 2.0
## Where the banks end at the gorge, and how the broken deck stubs reach out from there.
const BANK_EDGE_X := 5.0
const STUB_OVERLAP := 0.2
const STUB_LENGTH := 3.0
const STUB_DROOP := 0.2
## The rails run this far from the centre line, in the intact scene.
const RAIL_SPAN := 100.0
## Terrain this far past the bounds goes into the bake, so the navmesh reaches the map's edge.
const NAV_TERRAIN_MARGIN := 2.0
## A blocker cuts the navmesh from this far below its own bottom, so one standing on a slope still
## cuts the ground on its downhill side.
const BLOCKER_SINK := 2.0
const STANDING_RAY_TOP := 100.0
## How far below the deck still counts as on the span.
const SPAN_DEPTH := 1.5

## What the player is told. The defaults are the bridge mission's. What is asked of the player
## is in the Objectives node.
@export var title := "The bridge at dawn"
## The briefing's lines.
@export var briefing_lines := PackedStringArray([
	"Destroy the railway bridge with the Dynamiter's charge.",
	"Get both of them to the extraction point on the far bank.",
	"Lose either one and the mission fails.",
])

## A night mission: dark, lamp-lit, and with a searchlight sweeping from every watchtower.
@export var night := false

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
## The same for a target that is a stack of stores (Nav/TargetStack).
var _intact_stack: Node3D
## Only the newest deferred rebake runs.
var _rebake_request := 0
var _scenery_built := false


func _ready() -> void:
	# Before the rules exist, an objective can already say where it is.
	for o in objectives():
		o.setup(self, null)
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
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_intact_deck):
			_intact_deck.free()
		if is_instance_valid(_intact_stack):
			_intact_stack.free()


func specialists() -> Array[Specialist]:
	var out: Array[Specialist] = []
	for child in get_children():
		if child is Specialist:
			out.append(child)
	return out


## Those to be brought out: the Prisoner children.
func prisoners() -> Array[Prisoner]:
	var out: Array[Prisoner] = []
	for child in get_children():
		if child is Prisoner:
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


## What the mission asks for: the children of Objectives, in order.
func objectives() -> Array[Objective]:
	var out: Array[Objective] = []
	var holder := get_node_or_null("Objectives")
	if holder:
		for child in holder.get_children():
			if child is Objective:
				out.append(child)
	return out


func extraction() -> Area3D:
	return get_node_or_null("Extraction") as Area3D


## The mission's ground, when it has one: the Terrain directly under Nav/.
func terrain() -> Terrain:
	var region := _region()
	if region:
		for child in region.get_children():
			if child is Terrain:
				return child
	return null


## Height of the ground at a point on the ground plane. Maps without a Terrain are flat at 0.
func ground_height(x: float, z: float) -> float:
	var land := terrain()
	return land.height_at(x, z) if land else 0.0


func nav_map() -> RID:
	var region := _region()
	return region.get_navigation_map() if region else RID()


## Bakes the navigation mesh on the main thread (the web build has no threads) and
## syncs the navigation map so path queries work straight away.
## The source geometry is fed in procedurally from the CSG collision faces. Letting
## NavigationRegion3D.bake_navigation_mesh parse CSG nodes goes through RenderingServer
## meshes, which Godot warns about (GPU readback) and which fails the GUT run.
func build_nav() -> void:
	build_scenery()
	if not rebake_nav():
		return
	for guard in guards():
		guard.set_nav_map(nav_map())
		guard.start_patrol()
	for held in prisoners():
		held.set_nav_map(nav_map())


## Sets everything that stands on the land onto it, once: walls and buildings, and the spawn and
## route points, which are authored on the ground plane.
func build_scenery() -> void:
	if _scenery_built:
		return
	_scenery_built = true
	var ground := ground_height
	for node in find_children("*", "StaticBody3D", true, false):
		if node is StoneWall or node is Building:
			node.build(ground)
		elif node.has_method("stand"):
			node.stand(ground)
	# Scatters go last: they keep clear of the walls and buildings.
	for node in find_children("*", "Node3D", true, false):
		if node is PropScatter:
			node.build(self)
		elif node.has_method("settle"):
			node.settle(ground)
	if night:
		for node in find_children("*", "StaticBody3D", true, false):
			if node is Watchtower:
				(node as Watchtower).light_up(ground)
	if terrain() == null:
		return
	terrain().bake_shade(_shade_casters())
	for marker in specialist_spawns() + guard_spawns():
		marker.global_position.y = _standing_height(marker.global_position)
	var list := guards()
	var routes := patrol_routes()
	for i in list.size():
		list[i].global_position.y = _standing_height(list[i].global_position)
		if i < routes.size():
			var route := _route_points(routes[i])
			list[i].set_route(route)
			_guard_routes[String(list[i].name)] = route


## Everything that stands on the land and should sit in a pool of soft shade: walls, buildings,
## crates and other solid boxes, and each scattered tree and bush.
func _shade_casters() -> Array:
	var out := []
	for node in find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if not collision.shape is BoxShape3D or collision.get_parent() is Area3D:
			continue
		var size := (collision.shape as BoxShape3D).size
		var at := collision.global_position
		out.append({ "at": Vector2(at.x, at.z), "half": Vector2(size.x, size.z) / 2.0,
				"turn": collision.global_rotation.y, "reach": clampf(size.y * 0.8, 1.1, 2.4), "strength": 0.5 })
	for node in find_children("*", "CSGBox3D", true, false):
		var box := node as CSGBox3D
		if not box.use_collision or box.name == "BridgeDeck" or not box.get_parent() is NavigationRegion3D \
				and box.get_parent().name != "TargetStack":
			continue
		var at := box.global_position
		out.append({ "at": Vector2(at.x, at.z), "half": Vector2(box.size.x, box.size.z) / 2.0,
				"turn": box.global_rotation.y, "reach": 1.0, "strength": 0.5 })
	for node in find_children("*", "Node3D", true, false):
		var scatter := node as PropScatter
		if scatter == null or scatter.tree_kind == &"":
			continue
		var crown: float = TreeBuilder.KINDS[scatter.tree_kind]["crown"]
		for t in scatter.transforms():
			out.append({ "at": Vector2(t.origin.x, t.origin.z), "half": Vector2.ZERO,
					"reach": crown * t.basis.get_scale().y * 1.05, "strength": 0.34 })
	return out


## The height of whatever a unit would stand on at a point of the ground plane: the bridge deck
## where there is one, else the land. Needs the physics world, so the mission must be in the tree.
func _standing_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, STANDING_RAY_TOP, at.z),
			Vector3(at.x, -STANDING_RAY_TOP, at.z), Unit.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"].y if hit.has("position") else ground_height(at.x, at.z)


## Rebakes without touching the guards, for a map that changes mid-mission.
func rebake_nav() -> bool:
	var region := _region()
	if region == null or region.navigation_mesh == null:
		return false
	nav_bakes += 1
	var data := NavigationMeshSourceGeometryData3D.new()
	_collect_faces(region, region, data)
	NavigationServer3D.bake_from_source_geometry_data(region.navigation_mesh, data)
	_lower_to_ground(region.navigation_mesh)
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), region.navigation_mesh)
	NavigationServer3D.map_force_update(region.get_navigation_map())
	nav_rebaked.emit()
	return true


## Units take their height from the navmesh, so its surface has to be where the ground is.
func _lower_to_ground(navmesh: NavigationMesh) -> void:
	var lift := NAV_BAKE_LIFT_CELLS * navmesh.cell_height
	var vertices := navmesh.get_vertices()
	for i in vertices.size():
		vertices[i].y -= lift
	navmesh.set_vertices(vertices)


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


## Swaps the intact deck for broken stubs drooping out over the gorge from each bank, then rebakes
## the navmesh so nothing can path across the gorge. The stubs, and the girders and rails they
## replace, are meshes only: no collision, and the navmesh bake never sees them. Safe to call twice.
func break_bridge() -> void:
	var region := _region()
	if region == null:
		return
	_break_stack(region)
	var deck := get_node_or_null("Nav/BridgeDeck")
	if deck == null:
		return
	region.remove_child(deck)
	_intact_deck = deck
	var stubs := Node3D.new()
	stubs.name = "BridgeBroken"
	region.add_child(stubs)
	var csg := deck as CSGBox3D
	for sign in [-1.0, 1.0]:
		var root: float = sign * (BANK_EDGE_X + STUB_OVERLAP)
		var pivot := Node3D.new()
		stubs.add_child(pivot)
		pivot.position = Vector3(root, deck.position.y, deck.position.z)
		pivot.rotation.z = sign * STUB_DROOP
		pivot.add_child(_visual_box(Vector3(STUB_LENGTH, csg.size.y, csg.size.z), csg.material,
				Vector3(-sign * STUB_LENGTH / 2.0, 0.0, 0.0)))
		for z in [-0.7, 0.7]:
			var long_rail := get_node_or_null("Scenery/RailA") as CSGBox3D
			var rail_size := long_rail.size if long_rail else Vector3(0.0, 0.16, 0.12)
			var rail := _visual_box(Vector3(RAIL_SPAN - BANK_EDGE_X - STUB_OVERLAP, rail_size.y, rail_size.z),
					_scenery_material("RailA"),
					Vector3(sign * (RAIL_SPAN + BANK_EDGE_X + STUB_OVERLAP) / 2.0,
					long_rail.position.y if long_rail else 0.08, z))
			stubs.add_child(rail)
	_show_span(false)
	_rebake_next_frame()


## A target that is a stack of stores goes up: the stack leaves the map (and the navmesh, at the
## rebake) and a scorched, smoking patch is left where it stood. Safe to call twice.
func _break_stack(region: NavigationRegion3D) -> void:
	var stack := region.get_node_or_null("TargetStack") as Node3D
	if stack == null:
		return
	region.remove_child(stack)
	_intact_stack = stack
	var wreck := Node3D.new()
	wreck.name = "TargetWreck"
	add_child(wreck)
	var marker := get_node_or_null("BridgeTarget") as Node3D
	var at := marker.global_position if marker else Vector3.ZERO
	wreck.global_position = Vector3(at.x, ground_height(at.x, at.z) + 0.03, at.z)
	var scorch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.04
	disc.radial_segments = 20
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.06, 0.05, 0.05)
	soot.roughness = 1.0
	disc.material = soot
	scorch.mesh = disc
	wreck.add_child(scorch)
	var smoke := CPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 5.0
	smoke.direction = Vector3(0.2, 1.0, 0.1)
	smoke.spread = 14.0
	smoke.gravity = Vector3.ZERO
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.2
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(0.12, 0.12, 0.13, 0.5)
	puff.material = haze
	smoke.mesh = puff
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wreck.add_child(smoke)
	_rebake_next_frame()


## Whether a point is on the bridge's span over the gorge (not the abutments, not the gorge floor).
func on_span(pos: Vector3) -> bool:
	var deck := (_intact_deck if _intact_deck != null else get_node_or_null("Nav/BridgeDeck")) as CSGBox3D
	if deck == null:
		return false
	return absf(pos.x - deck.position.x) < BANK_EDGE_X and absf(pos.z - deck.position.z) <= deck.size.z / 2.0 + 0.3 \
			and pos.y > deck.position.y - SPAN_DEPTH


## Undoes break_bridge, for a load whose save has the bridge whole. Safe to call on a whole bridge.
func repair_bridge() -> void:
	var region := _region()
	if region == null:
		return
	if _intact_stack != null:
		var wreck := get_node_or_null("TargetWreck")
		if wreck != null:
			wreck.free()
		region.add_child(_intact_stack)
		_intact_stack = null
		_rebake_next_frame()
	if _intact_deck == null:
		return
	var stubs := region.get_node_or_null("BridgeBroken")
	if stubs != null:
		stubs.free()
	region.add_child(_intact_deck)
	_intact_deck = null
	_show_span(true)
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
	var prisoner_states: Array[Dictionary] = []
	for held in prisoners():
		prisoner_states.append(held.save_state())
	return {
		"mission": scene_file_path,
		"specialists": specialist_states,
		"prisoners": prisoner_states,
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
	for e in d["prisoners"]:
		var held := get_node(NodePath(e["id"])) as Prisoner
		held.follow(by_id.get(e["leader"]) as Specialist)
		held.load_state(e)
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


## For something on the map that has just opened or shut a way: bakes the navmesh again on the
## next frame.
func rebake_nav_soon() -> void:
	_rebake_next_frame()


## CSG builds its geometry on the next idle frame, so the rebake waits one frame (callers need not
## await it). A newer request, or leaving the tree, cancels an older one.
func _rebake_next_frame() -> void:
	_rebake_request += 1
	var request := _rebake_request
	await get_tree().process_frame
	if request == _rebake_request and is_inside_tree():
		rebake_nav()


func _visual_box(size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


func _scenery_material(node_name: String) -> Material:
	var node := get_node_or_null("Scenery/" + node_name) as CSGBox3D
	return node.material if node else null


## The girders, the long rails and the deck's sleepers belong to the intact bridge.
func _show_span(shown: bool) -> void:
	for node_name in ["GirderN", "GirderS", "RailA", "RailB", "DeckSleepers"]:
		var node := get_node_or_null("Scenery/" + node_name) as Node3D
		if node:
			node.visible = shown
			# A girder that blocks sight stops doing so when it is gone.
			if node is CSGShape3D and node_name.begins_with("Girder"):
				(node as CSGShape3D).use_collision = shown


func _route_points(route: Path3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in route.curve.point_count:
		var p := route.to_global(route.curve.get_point_position(i))
		if terrain() != null and is_inside_tree():
			p.y = _standing_height(p)
		points.append(p)
	return points


## What the bake sees under Nav/: the terrain inside the bounds, CSG shapes, and the box and
## triangle-mesh collision shapes of static bodies (walls, buildings, tree trunks, rocks).
func _collect_faces(node: Node, region: NavigationRegion3D, data: NavigationMeshSourceGeometryData3D) -> void:
	var to_local := region.global_transform.affine_inverse()
	for child in node.get_children():
		var csg := child as CSGShape3D
		if child is Terrain:
			var land := child as Terrain
			data.add_faces(land.faces(bounds_rect.grow(NAV_TERRAIN_MARGIN)), to_local * land.global_transform)
			continue
		if csg and csg.is_root_shape():
			var shape := csg.bake_collision_shape()
			if shape:
				data.add_faces(shape.get_faces(), to_local * csg.global_transform)
		elif child is CollisionShape3D and child.get_parent() is StaticBody3D:
			_collect_shape(child as CollisionShape3D, to_local, data, region.navigation_mesh.agent_radius)
		_collect_faces(child, region, data)


## A box is cut out of the navmesh over its footprint, grown by the agent's radius (its faces alone
## would leave walkable ground inside it and on its roof). A triangle mesh goes in as faces.
static func _collect_shape(collision: CollisionShape3D, to_local: Transform3D,
		data: NavigationMeshSourceGeometryData3D, agent_radius: float) -> void:
	var xform := to_local * collision.global_transform
	if collision.shape is ConcavePolygonShape3D:
		data.add_faces((collision.shape as ConcavePolygonShape3D).get_faces(), xform)
	elif collision.shape is BoxShape3D:
		var h := (collision.shape as BoxShape3D).size / 2.0
		var outline := PackedVector3Array()
		var low := INF
		var high := -INF
		var gx := h.x + agent_radius
		var gz := h.z + agent_radius
		for corner in [Vector3(-gx, 0, -gz), Vector3(gx, 0, -gz), Vector3(gx, 0, gz), Vector3(-gx, 0, gz)]:
			outline.append(xform * (corner as Vector3))
		for y in [-h.y, h.y]:
			for corner in [Vector3(-h.x, y, -h.z), Vector3(h.x, y, h.z), Vector3(h.x, y, -h.z), Vector3(-h.x, y, h.z)]:
				var world_y: float = (xform * (corner as Vector3)).y
				low = minf(low, world_y)
				high = maxf(high, world_y)
		data.add_projected_obstruction(outline, low - BLOCKER_SINK, high - low + BLOCKER_SINK, true)


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
