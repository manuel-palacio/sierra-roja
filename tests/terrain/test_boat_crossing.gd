extends GutTest
## Boats that cross the water once an objective is met. Display only.

var mission: Mission
var objective: Objective
var crossing: BoatCrossing


func before_each() -> void:
	mission = Mission.new()
	var holder := Node.new()
	holder.name = "Objectives"
	mission.add_child(holder)
	objective = Objective.new()
	objective.name = "Silence"
	holder.add_child(objective)
	crossing = BoatCrossing.new()
	crossing.after = NodePath("Objectives/Silence")
	crossing.seconds = 2.0
	crossing.level = 0.4
	crossing.starts = PackedVector2Array([Vector2(0, -60), Vector2(10, -62)])
	crossing.ends = PackedVector2Array([Vector2(0, -20), Vector2(10, -20)])
	mission.add_child(crossing)
	add_child_autofree(mission)
	await get_tree().process_frame


func _at(index: int) -> Vector3:
	return crossing.boats()[index].global_position


func test_the_boats_wait_until_the_objective_is_met() -> void:
	assert_eq(crossing.boats().size(), 2)
	await wait_process_frames(30)
	assert_false(crossing.crossing)
	assert_almost_eq(_at(0), Vector3(0, 0.4, -60), Vector3.ONE * 0.01)
	objective.complete()
	assert_true(crossing.crossing)


func test_they_cross_in_the_time_given_and_stop_at_the_far_bank() -> void:
	objective.complete()
	crossing._process(1.0)
	assert_almost_eq(_at(0).z, -40.0, 0.05, "half way at half time")
	crossing._process(1.0)
	crossing._process(5.0)
	assert_almost_eq(_at(0), Vector3(0, 0.4, -20), Vector3.ONE * 0.01)
	assert_almost_eq(_at(1), Vector3(10, 0.4, -20), Vector3.ONE * 0.01)
	assert_eq(crossing.progress(), 1.0)


func test_starting_twice_is_starting_once() -> void:
	crossing.start()
	crossing._process(1.0)
	crossing.start()
	assert_almost_eq(crossing.progress(), 0.5, 0.01, "not set back to the start")


func test_arrive_puts_them_across_at_once() -> void:
	crossing.arrive()
	assert_almost_eq(_at(1), Vector3(10, 0.4, -20), Vector3.ONE * 0.01)


func test_a_load_puts_them_where_the_objective_says() -> void:
	crossing.arrive()
	mission.state_loaded.emit()
	assert_eq(crossing.progress(), 0.0, "not met in the save: back on the far side")
	assert_false(crossing.crossing)
	objective.done = true
	mission.state_loaded.emit()
	assert_eq(crossing.progress(), 1.0, "met in the save: come in")


func test_they_stop_nothing_and_nobody() -> void:
	assert_eq(crossing.find_children("*", "CollisionObject3D", true, false).size(), 0)
