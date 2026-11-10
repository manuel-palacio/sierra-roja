class_name ShotDisplay
extends Node3D
## Shows every shot: a bright streak from the muzzle to where it was aimed, and a flash at the
## muzzle, both gone in a moment. It listens to each unit's `acted` and never changes game state.

const STREAK_SECONDS := 0.16
const FLASH_SECONDS := 0.07
const STREAK_COLOR := Color(1.0, 0.92, 0.6)
const STREAK_WIDTH := 0.05
## Where a standing or a lying shooter's muzzle is, and how high on the target the shot lands.
const MUZZLE_STANDING := 1.75
const MUZZLE_LYING := 0.45
const MUZZLE_AHEAD := 0.9
const HIT_HEIGHT := 1.3
const SHOTS: Array[StringName] = [&"rifle", &"pistol"]

## Live streaks and flashes, oldest first.
var streaks: Array[MeshInstance3D] = []
var flashes: Array[Node3D] = []

var _streak_age: Array[float] = []
var _flash_age: Array[float] = []
var _hooked := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for group in [Guard.GROUP, Specialist.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			_hook(node)


func streak_length(streak: MeshInstance3D) -> float:
	return streak.scale.z


func _process(delta: float) -> void:
	for i in range(streaks.size() - 1, -1, -1):
		_streak_age[i] += delta
		var left := 1.0 - _streak_age[i] / STREAK_SECONDS
		if left <= 0.0:
			streaks[i].queue_free()
			streaks.remove_at(i)
			_streak_age.remove_at(i)
		else:
			(streaks[i].material_override as StandardMaterial3D).albedo_color.a = left
	for i in range(flashes.size() - 1, -1, -1):
		_flash_age[i] += delta
		if _flash_age[i] >= FLASH_SECONDS:
			flashes[i].queue_free()
			flashes.remove_at(i)
			_flash_age.remove_at(i)


func _on_node_added(node: Node) -> void:
	if node is Unit:
		_hook(node)


func _hook(node: Node) -> void:
	var unit := node as Unit
	if unit == null or _hooked.has(unit.get_instance_id()):
		return
	_hooked[unit.get_instance_id()] = true
	unit.acted.connect(_on_acted.bind(unit))


func _on_acted(what: StringName, at: Vector3, unit: Unit) -> void:
	if not what in SHOTS or not is_instance_valid(unit):
		return
	var target := at + Vector3.UP * HIT_HEIGHT
	var lying := unit.stance == Unit.Stance.CRAWLING
	var chest := unit.global_position + Vector3.UP * (MUZZLE_LYING if lying else MUZZLE_STANDING)
	var toward := target - chest
	toward.y = 0.0
	var muzzle := chest + toward.normalized() * minf(MUZZLE_AHEAD, toward.length() * 0.5)
	var length := muzzle.distance_to(target)
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(STREAK_WIDTH, STREAK_WIDTH, 1.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = STREAK_COLOR
	var streak := MeshInstance3D.new()
	streak.mesh = mesh
	streak.material_override = material
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streak)
	var up := Vector3.UP if absf((target - muzzle).normalized().y) < 0.99 else Vector3.RIGHT
	streak.global_transform = Transform3D(Basis.looking_at(target - muzzle, up), (muzzle + target) / 2.0)
	streak.scale = Vector3(1.0, 1.0, length)
	streaks.append(streak)
	_streak_age.append(0.0)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.45)
	flash.light_energy = 3.0
	flash.omni_range = 6.0
	var spark := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	ball.radial_segments = 6
	ball.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.9, 0.55)
	ball.material = glow
	spark.mesh = ball
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(spark)
	add_child(flash)
	flash.global_position = muzzle
	flashes.append(flash)
	_flash_age.append(0.0)
