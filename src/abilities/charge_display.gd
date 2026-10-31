class_name ChargeDisplay
extends Node3D
## Display only: gives each planted charge a small mesh and each detonation a brief flash. Charges
## are created at runtime and by a load, so it finds them as they enter the tree, as MissionRules
## does. It reads their signals, changes no rules state, and adds nothing a ray can hit.

const FLASH_SECONDS := 0.5
## The flash's largest radius, in metres.
const FLASH_RADIUS := 6.0
const FLASH_COLOR := Color(1.0, 0.75, 0.35)
const CHARGE_COLOR := Color(1.0, 0.3, 0.1)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for charge in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		_hook(charge)


func _on_node_added(node: Node) -> void:
	if node is PlantedCharge:
		_hook(node)


func _hook(charge: PlantedCharge) -> void:
	charge.add_child(_charge_mesh())
	charge.detonated.connect(_flash)


func _charge_mesh() -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.28
	mesh.height = 0.35
	mesh.material = _unshaded(CHARGE_COLOR)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = mesh.height / 2.0
	return instance


func _flash(pos: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var material := _unshaded(FLASH_COLOR)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	var light := OmniLight3D.new()
	light.light_color = FLASH_COLOR
	light.light_energy = 6.0
	light.omni_range = FLASH_RADIUS * 4.0
	var flash := Node3D.new()
	flash.add_child(ball)
	flash.add_child(light)
	add_child(flash)
	flash.global_position = pos
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * FLASH_RADIUS, FLASH_SECONDS)
	tween.tween_property(material, "albedo_color:a", 0.0, FLASH_SECONDS)
	tween.tween_property(light, "light_energy", 0.0, FLASH_SECONDS)
	tween.chain().tween_callback(flash.queue_free)


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
