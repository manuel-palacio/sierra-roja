class_name Searchlight
extends Node3D
## A searchlight on a watchtower at night. Its beam sweeps a spot of light back and forth over the
## ground. A living specialist standing in the spot, with nothing between them and the lamp, is
## seen: every guard is sent to that place in alarm. Someone lying down is passed over, as in a
## guard's far zone. Sits at the lamp; the tower gives it its aim.

signal caught(unit: Unit, at: Vector3)

## Radius of the lit spot on the ground, in metres.
const SPOT := 3.6
## Seconds before the same light can raise the alarm again.
const COOLDOWN := 2.0
const BEAM_COLOR := Color(0.92, 0.95, 1.0)
const CHEST := 1.2

## Which way the middle of the sweep points on the ground plane, in degrees: 0 east, 90 south.
@export var aim_deg := 0.0
## How far either side of that the beam swings, in degrees.
@export var arc_deg := 50.0
## How far from the tower the spot travels, in metres.
@export var reach := 14.0
## Seconds for one swing from side to side and back.
@export var period := 10.0

## Where the middle of the spot is now, on the ground.
var spot := Vector3.ZERO

var _time := 0.0
var _quiet := 0.0
var _ground := Callable()
var _light: SpotLight3D
var _pool: MeshInstance3D


## ground.call(x, z) gives the ground height under the spot.
func setup(ground: Callable) -> void:
	_ground = ground
	_light = SpotLight3D.new()
	_light.light_color = BEAM_COLOR
	_light.light_energy = 7.0
	_light.spot_range = reach + 14.0
	_light.spot_angle = rad_to_deg(atan2(SPOT, reach)) + 2.0
	_light.spot_angle_attenuation = 0.6
	add_child(_light)
	# A pale pool on the ground under the beam, so the lit spot reads from any angle.
	var disc := CylinderMesh.new()
	disc.top_radius = SPOT
	disc.bottom_radius = SPOT
	disc.height = 0.02
	disc.radial_segments = 28
	disc.rings = 1
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(BEAM_COLOR, 0.13)
	disc.material = glow
	_pool = MeshInstance3D.new()
	_pool.mesh = disc
	_pool.top_level = true
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	sweep(0.0)


func _physics_process(delta: float) -> void:
	sweep(delta)


## One step of the sweep and of the watch it keeps. Tests call this directly.
func sweep(delta: float) -> void:
	_time += delta
	_quiet = maxf(_quiet - delta, 0.0)
	var swing := sin(_time * TAU / maxf(period, 0.1))
	var heading := deg_to_rad(aim_deg + arc_deg * swing)
	var x := global_position.x + cos(heading) * reach
	var z := global_position.z + sin(heading) * reach
	spot = Vector3(x, _ground.call(x, z) if _ground.is_valid() else 0.0, z)
	if _light != null and is_inside_tree():
		_light.look_at(spot, Vector3.UP)
		_pool.global_position = spot + Vector3.UP * 0.12
	if _quiet > 0.0 or not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(Unit.HUNTED):
		var s := node as Unit
		if catches(s):
			_quiet = COOLDOWN
			caught.emit(s, s.global_position)
			for guard_node in get_tree().get_nodes_in_group(Guard.GROUP):
				var guard := guard_node as Guard
				if guard.alive:
					guard.brain.on_alarm(s.global_position)
			return


## Whether the beam shows this unit to the tower right now.
func catches(s: Unit) -> bool:
	if s == null or not s.alive or s.stance != Unit.Stance.STANDING:
		return false
	var away := Vector2(s.global_position.x - spot.x, s.global_position.z - spot.z).length()
	if away > SPOT:
		return false
	return Perception.line_clear(self, global_position, s.global_position + Vector3.UP * CHEST)
