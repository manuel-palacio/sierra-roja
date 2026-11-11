class_name Campfire
extends Node3D
## A small fire: a ring of stones with logs, flames, a thread of smoke and a warm light that
## flickers. Marks the extraction point, where the squad's friends are waiting. Display only.

const STONES := preload("res://assets/props/nature/campfire_stones.glb")
const LOGS := preload("res://assets/props/nature/campfire_logs.glb")
const MODEL_SCALE := 3.2
const LIGHT_ENERGY := 2.2
const FLICKER := 0.3

var light: OmniLight3D
var flames: CPUParticles3D
var smoke: CPUParticles3D

var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	for scene: PackedScene in [STONES, LOGS]:
		var model := scene.instantiate() as Node3D
		model.scale = Vector3.ONE * MODEL_SCALE
		add_child(model)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).mesh = PropScatter.in_palette((node as MeshInstance3D).mesh)
	light = OmniLight3D.new()
	light.position = Vector3(0, 0.9, 0)
	light.light_color = Color(1.0, 0.62, 0.25)
	light.light_energy = LIGHT_ENERGY
	light.omni_range = 9.0
	add_child(light)
	flames = _particles(Color(1.0, 0.55, 0.12, 0.9), 0.16, 22, 0.7, 1.3, Vector3(0, 0.35, 0))
	flames.scale_amount_min = 0.5
	flames.scale_amount_max = 1.2
	smoke = _particles(Color(0.7, 0.7, 0.72, 0.28), 0.3, 12, 4.5, 0.7, Vector3(0, 1.0, 0))
	smoke.direction = Vector3(0.25, 1.0, 0.1)
	_noise.frequency = 1.6


func _process(delta: float) -> void:
	_time += delta
	light.light_energy = LIGHT_ENERGY * (1.0 + _noise.get_noise_1d(_time * 4.0) * FLICKER)


func _particles(color: Color, radius: float, amount: int, lifetime: float, speed: float, at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 6
	ball.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	ball.material = material
	p.mesh = ball
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
