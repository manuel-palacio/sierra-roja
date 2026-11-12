extends GutTest


func test_noise_radius_picks_the_sound() -> void:
	assert_eq(SoundEffects.classify(8.0), SoundEffects.Kind.FOOTSTEP)
	assert_eq(SoundEffects.classify(20.0), SoundEffects.Kind.SHOT)
	assert_eq(SoundEffects.classify(35.0), SoundEffects.Kind.SHOT)
	assert_eq(SoundEffects.classify(80.0), SoundEffects.Kind.EXPLOSION)


func test_listens_to_noise_without_touching_it() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	NoiseBus.emit_noise(Vector3.ZERO, 35.0)
	assert_eq(fx.voices().size(), 1, "one voice for the shot")
	assert_true(fx.voices()[0] is AudioStreamPlayer3D)


func test_alarm_plays_once_within_the_cooldown() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	fx._on_alarm(Vector3.ZERO)
	fx._on_alarm(Vector3.ZERO)
	assert_eq(fx.voices().size(), 1)


func test_the_morning_is_heard_from_the_start_and_keeps_going() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	assert_not_null(fx.ambience)
	assert_eq(fx.ambience.stream, SoundEffects.AMBIENCE)
	assert_true((fx.ambience.stream as AudioStreamOggVorbis).loop, "birdsong loops")
	assert_lt(fx.ambience.volume_db, -8.0, "under everything else")
	assert_eq(fx.voices().size(), 0, "and is not counted as a voice")


func _unit(scene: String) -> Unit:
	var unit: Unit = load(scene).instantiate()
	add_child_autofree(unit)
	unit.set_physics_process(false)
	return unit


func test_a_knife_is_heard_and_a_shot_is_not_doubled() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	var dynamiter := _unit("res://scenes/units/specialist.tscn")
	await get_tree().process_frame
	dynamiter.acted.emit(&"knife", Vector3(1, 0, 0))
	assert_eq(fx.voices().size(), 1)
	assert_eq((fx.voices()[0] as AudioStreamPlayer3D).stream, SoundEffects.KNIFE)
	dynamiter.acted.emit(&"pistol", Vector3(5, 0, 0))
	assert_eq(fx.voices().size(), 1, "the shot's sound comes with its noise, not twice")


func test_a_guard_falling_is_heard_when_it_lands() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	var guard := _unit("res://scenes/units/guard.tscn")
	await get_tree().process_frame
	guard.take_damage(1000)
	assert_eq(fx.voices().size(), 0, "not yet: it is still falling")
	await wait_seconds(SoundEffects.FALL_SECONDS + 0.15)
	assert_eq(fx.voices().size(), 1)
	assert_eq((fx.voices()[0] as AudioStreamPlayer3D).stream, SoundEffects.BODY_FALL)
	for body in get_tree().get_nodes_in_group(Body.GROUP):
		body.free()


func test_a_body_that_was_already_lying_there_makes_no_sound() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	var body: Body = load(Body.SCENE).instantiate()
	add_child_autofree(body)
	await wait_seconds(SoundEffects.FALL_SECONDS + 0.15)
	assert_eq(fx.voices().size(), 0)
