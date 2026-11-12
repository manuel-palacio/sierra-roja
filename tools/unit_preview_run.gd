extends Node3D
## The work of tools/unit_preview.gd, which loads this once the autoloads exist.

const SCENES := ["res://scenes/units/guard.tscn", "res://scenes/units/specialist.tscn",
		"res://scenes/units/marksman.tscn", "res://scenes/units/body.tscn"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "unit_preview.png"
	var animation: String = args[1] if args.size() > 1 else ""
	var at: float = float(args[2]) if args.size() > 2 else 0.4
	var yaw: float = float(args[3]) if args.size() > 3 else 45.0
	var view: float = float(args[4]) if args.size() > 4 else 3.6
	var look_at_height: float = float(args[5]) if args.size() > 5 else 0.9
	var pitch: float = float(args[6]) if args.size() > 6 else -35.0
	get_window().size = Vector2i(1200, 520)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	# From over the camera's shoulder, so whatever faces the camera is lit.
	sun.rotation_degrees = Vector3(-40, yaw + 25.0, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(30, 30)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.31, 0.35, 0.19)
	ground.material_override = ground_material
	add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view
	camera.rotation_degrees = Vector3(pitch, yaw, 0)
	add_child(camera)
	camera.position = Vector3(0, look_at_height, 0) + camera.basis.z * 20.0
	camera.current = true
	for i in SCENES.size():
		var unit: Node3D = load(SCENES[i]).instantiate()
		unit.set_physics_process(false)
		add_child(unit)
		unit.position = camera.basis.x * (i - (SCENES.size() - 1) / 2.0) * 1.9
		if animation == "crawl" and unit is Unit:
			(unit as Unit).set_stance(Unit.Stance.CRAWLING)
		elif animation == "crawlmove" and unit is Unit:
			(unit as Unit).set_stance(Unit.Stance.CRAWLING)
			(unit as Unit).velocity = Vector3(0, 0, -1.2)
		elif animation == "walk" and unit is Unit:
			(unit as Unit).velocity = Vector3(0, 0, -3.0)
		elif animation == "run" and unit is Unit:
			(unit as Unit).velocity = Vector3(0, 0, -6.0)
		elif animation == "shoot" and unit is Unit:
			(unit as Unit).acted.emit(&"pistol" if i == 1 else &"rifle", Vector3.ZERO)
		elif animation == "stab" and unit is Unit:
			(unit as Unit).acted.emit(&"knife" if i == 1 else &"pistol", Vector3.ZERO)
		elif animation != "" and animation != "idle" and unit is Unit:
			unit.get_node("UnitVisual").set_process(false)
			for player in unit.find_children("*", "AnimationPlayer", true, false):
				(player as AnimationPlayer).play(animation)
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("wrote ", out_path)
	get_tree().quit()
