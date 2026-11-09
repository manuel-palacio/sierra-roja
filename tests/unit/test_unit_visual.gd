extends GutTest
## What a unit looks like: its uniform, where its model stands, and a body left behind.

const GUARD := "res://scenes/units/guard.tscn"
const DYNAMITER := "res://scenes/units/specialist.tscn"
const MARKSMAN := "res://scenes/units/marksman.tscn"


func _unit(scene: String) -> Unit:
	var unit: Unit = load(scene).instantiate()
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(unit)
	return unit


func _textures(root: Node) -> Dictionary:
	var out := {}
	for node in root.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		out[material.albedo_texture.resource_path.get_file()] = true
	return out


func test_each_unit_wears_its_own_uniform() -> void:
	assert_eq(_textures(_unit(GUARD)).keys(), ["uniform-guard.png"])
	assert_eq(_textures(_unit(DYNAMITER)).keys(), ["uniform-dynamiter.png"])
	assert_eq(_textures(_unit(MARKSMAN)).keys(), ["uniform-marksman.png"])


func test_a_body_is_the_guard_lying_down_in_uniform() -> void:
	var body: Body = load(Body.SCENE).instantiate()
	add_child_autofree(body)
	await get_tree().process_frame
	assert_eq(_textures(body).keys(), ["uniform-guard.png"])
	var player := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	assert_eq(player.assigned_animation, "die")
	assert_almost_eq(player.current_animation_position, player.get_animation("die").length, 0.05, "already down")
	assert_false(player.is_playing(), "and staying down")


## Ground that the navmesh floats 0.3 m above: the unit stands at navmesh height and its model is
## let down onto what is drawn.
func test_the_model_stands_on_the_drawn_ground() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(10, 1, 10)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)  # top at y = 0
	var unit: Unit = load(DYNAMITER).instantiate()
	add_child_autofree(unit)
	unit.set_physics_process(false)
	unit.global_position = Vector3(0, 0.3, 0)
	await wait_physics_frames(3)
	await get_tree().process_frame
	var model := unit.get_node("Model") as Node3D
	assert_almost_eq(model.global_position.y, 0.0, 0.02, "feet on the floor")
	unit.global_position = Vector3(0, 0.9, 0)
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_almost_eq(model.position.y, -UnitVisual.MAX_GROUND_SHIFT, 0.001, "but never moved far from the unit")
	unit.global_position = Vector3(50, 0.0, 0)  # nothing under it at all
	await wait_physics_frames(2)
	await get_tree().process_frame
	assert_almost_eq(model.position.y, 0.0, 0.001)
