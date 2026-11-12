extends Node3D
## The work of tools/portrait_render.gd, which loads this once the autoloads exist.

const UNITS := { "dynamiter": "res://scenes/units/specialist.tscn", "marksman": "res://scenes/units/marksman.tscn",
		"guard": "res://scenes/units/guard.tscn" }


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "."
	get_window().size = Vector2i(512, 512)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.20, 0.19, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.70)
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 215, 0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.25
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.82
	# Units face -z; the camera looks back at them from a little to one side and above.
	camera.rotation_degrees = Vector3(-7, 196, 0)
	add_child(camera)
	camera.position = Vector3(0, 2.0, 0) + camera.basis.z * 10.0
	camera.current = true
	for key in UNITS:
		var unit: Node3D = load(UNITS[key]).instantiate()
		unit.set_physics_process(false)
		add_child(unit)
		for ring in unit.find_children("Ring", "MeshInstance3D", true, false):
			ring.visible = false
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % key))
		unit.free()
		await get_tree().process_frame
	print("wrote portraits to ", out_dir)
	get_tree().quit()
