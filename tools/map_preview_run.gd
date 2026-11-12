extends Node
## The work of tools/map_preview.gd, which loads this once the autoloads exist.
## Design aid: writes a top-down picture of a mission after its navmesh bake.
##   godot --headless --path . -s tools/map_preview.gd -- out.png [res://path/to/mission.tscn]
## Height is shown as shading (lighter is higher), ground too steep to walk in dark red, navmesh
## polygons outlined in green, blockers in black, patrol routes in orange with a dot at the start,
## specialist spawns in blue, the extraction in bright green, and a grid line every 10 m (the lines
## through x = 0 and z = 0 are white).

const SCALE := 8  # pixels per metre
const MARGIN := 4.0


func _ready() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "map_preview.png"
	var scene: String = args[1] if args.size() > 1 else "res://scenes/missions/bridge.tscn"
	var mission: Mission = load(scene).instantiate()
	add_child(mission)
	for guard in mission.guards():
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await get_tree().physics_frame
	var started := Time.get_ticks_msec()
	mission.build_nav()
	print("nav bake: %d ms" % (Time.get_ticks_msec() - started))
	var area := mission.bounds_rect.grow(MARGIN)
	var size := Vector2i(int(area.size.x * SCALE), int(area.size.y * SCALE))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var land := mission.terrain()
	var lo := INF
	var hi := -INF
	if land:
		for r in land.field.rows:
			for c in land.field.cols:
				var h := land.field.get_h(c, r)
				if h > -6.0:
					lo = minf(lo, h)
					hi = maxf(hi, h)
	for py in size.y:
		for px in size.x:
			var x := area.position.x + (px + 0.5) / SCALE
			var z := area.position.y + (py + 0.5) / SCALE
			var color := Color(0.3, 0.3, 0.3)
			if land:
				var h := land.height_at(x, z)
				var t := clampf(inverse_lerp(lo, hi, h), 0.0, 1.0)
				color = Color(0.25, 0.32, 0.22).lerp(Color(0.85, 0.85, 0.7), t)
				if h < -6.0:
					color = Color(0.15, 0.25, 0.5)
				elif land.field.slope_deg_at(x, z) > 35.0:
					color = Color(0.45, 0.2, 0.2)
			if not mission.bounds_rect.has_point(Vector2(x, z)):
				color = color.darkened(0.5)
			img.set_pixel(px, py, color)
	var to_px := func(p: Vector3) -> Vector2:
		return Vector2((p.x - area.position.x) * SCALE, (p.z - area.position.y) * SCALE)
	for g in range(int(ceilf(area.position.x / 10.0)) * 10, int(area.end.x) + 1, 10):
		_line(img, to_px.call(Vector3(g, 0, area.position.y)), to_px.call(Vector3(g, 0, area.end.y)),
				Color.WHITE if g == 0 else Color(0, 0, 0, 1), 0.35 if g != 0 else 0.6)
	for g in range(int(ceilf(area.position.y / 10.0)) * 10, int(area.end.y) + 1, 10):
		_line(img, to_px.call(Vector3(area.position.x, 0, g)), to_px.call(Vector3(area.end.x, 0, g)),
				Color.WHITE if g == 0 else Color(0, 0, 0, 1), 0.35 if g != 0 else 0.6)
	var navmesh := (mission.get_node("Nav") as NavigationRegion3D).navigation_mesh
	var verts := navmesh.get_vertices()
	for i in navmesh.get_polygon_count():
		var poly := navmesh.get_polygon(i)
		for j in poly.size():
			_line(img, to_px.call(verts[poly[j]]), to_px.call(verts[poly[(j + 1) % poly.size()]]), Color(0.1, 0.9, 0.2), 0.55)
	for node in mission.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape.shape is BoxShape3D and not shape.get_parent() is Area3D:
			var h := (shape.shape as BoxShape3D).size / 2.0
			var corners: Array[Vector2] = []
			for c in [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]:
				corners.append(to_px.call(shape.global_transform * (c as Vector3)))
			for j in 4:
				_line(img, corners[j], corners[(j + 1) % 4], Color.BLACK, 1.0)
	for node in mission.find_children("*", "CSGBox3D", true, false):
		var box := node as CSGBox3D
		if box.use_collision:
			var h := box.size / 2.0
			_rect(img, to_px.call(box.global_position - h), to_px.call(box.global_position + h), Color(0.1, 0.1, 0.1))
	for guard in mission.guards():
		var route := mission.guard_route(String(guard.name))
		for j in route.size():
			_line(img, to_px.call(route[j]), to_px.call(route[(j + 1) % route.size()]), Color(1.0, 0.55, 0.0), 1.0)
		if not route.is_empty():
			_dot(img, to_px.call(route[0]), 4, Color(1.0, 0.3, 0.0))
	for spawn in mission.specialist_spawns():
		_dot(img, to_px.call(spawn.global_position), 4, Color(0.2, 0.5, 1.0))
	if mission.extraction():
		_dot(img, to_px.call(mission.extraction().global_position), 6, Color(0.2, 1.0, 0.3))
	for o in mission.objectives():
		_dot(img, to_px.call(o.marker_position()), 4, Color(1, 1, 0))
	img.save_png(out_path)
	for message in MissionValidator.validate(mission):
		print("INVALID: ", message)
	print("wrote ", out_path, " (", size.x, "x", size.y, ", ", SCALE, " px/m, top-left = ", area.position, ")")
	get_tree().quit()


func _line(img: Image, a: Vector2, b: Vector2, color: Color, alpha: float) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_blend(img, int(p.x), int(p.y), color, alpha)


func _rect(img: Image, a: Vector2, b: Vector2, color: Color) -> void:
	for y in range(int(minf(a.y, b.y)), int(maxf(a.y, b.y)) + 1):
		for x in range(int(minf(a.x, b.x)), int(maxf(a.x, b.x)) + 1):
			_blend(img, x, y, color, 0.8)


func _dot(img: Image, p: Vector2, radius: int, color: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				_blend(img, int(p.x) + x, int(p.y) + y, color, 1.0)


func _blend(img: Image, x: int, y: int, color: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).lerp(color, alpha))
