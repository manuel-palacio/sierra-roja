extends Node3D
## The work of tools/model_preview.gd, which loads this once the autoloads exist.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "model_preview.png"
	var model_path: String = args[1] if args.size() > 1 else "res://assets/buildings/farmhouse.glb"
	var view: float = float(args[2]) if args.size() > 2 else 15.0
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
	var old := Building.new()
	old.size = Vector3(8.0, 3.0, 5.5)
	old.roof_height = 1.7
	add_child(old)
	old.position = -camera.basis.x * 7.0
	old.build(func(_x: float, _z: float) -> float: return 0.0)
	var model: Node3D = (load(model_path) as PackedScene).instantiate()
	add_child(model)
	model.position = camera.basis.x * 7.0
	# The model's colour is painted on its vertices, shade and all.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false
			(node as MeshInstance3D).set_surface_override_material(i, material)
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
