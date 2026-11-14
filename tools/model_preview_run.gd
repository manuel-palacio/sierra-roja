extends Node3D
## The work of tools/model_preview.gd, which loads this once the autoloads exist.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "model_preview.png"
	var numbers: Array[float] = [9.0, 3.0, 5.0, 1.4]
	for i in 4:
		if args.size() > i + 1:
			numbers[i] = float(args[i + 1])
	var size := Vector3(numbers[0], numbers[1], numbers[2])
	var roof := numbers[3]
	var storeys: int = int(args[5]) if args.size() > 5 else 1
	var snowy: bool = args.size() > 6 and args[6] == "1"
	var view: float = float(args[7]) if args.size() > 7 else 16.0
	get_window().size = Vector2i(1400, 700)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.3, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 100, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(80, 80)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.42, 0.44, 0.26)
	ground.material_override = ground_material
	add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view
	camera.rotation_degrees = Vector3(-35, 45, 0)
	add_child(camera)
	camera.position = Vector3(0, 1.5, 0) + camera.basis.z * 40.0
	camera.current = true
	# Left, made of plain shapes; right, the same building drawn from its model.
	var plain := Building.new()
	plain.size = size
	plain.roof_height = roof
	plain.storeys = storeys
	plain.snowy = snowy
	plain.style = &"plain shapes"   # no model has this name, so it is built in code, as plaster looks
	add_child(plain)
	plain.position = -camera.basis.x * 7.0
	plain.build(func(_x: float, _z: float) -> float: return 0.0)
	var modelled := Building.new()
	modelled.size = size
	modelled.roof_height = roof
	modelled.storeys = storeys
	modelled.snowy = snowy
	add_child(modelled)
	modelled.position = camera.basis.x * 7.0
	modelled.build(func(_x: float, _z: float) -> float: return 0.0)
	for scene in ["res://scenes/units/guard.tscn", "res://scenes/units/specialist.tscn"]:
		for side in [-1.0, 1.0]:
			var unit: Node3D = load(scene).instantiate()
			unit.set_physics_process(false)
			add_child(unit)
			unit.position = camera.basis.x * 7.0 * side + Vector3(1.5 if scene.contains("guard") else -1.5, 0, 5.2)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("wrote ", out_path)
	get_tree().quit()
