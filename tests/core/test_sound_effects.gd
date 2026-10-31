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
	assert_eq(fx.get_child_count(), 1, "one voice for the shot")
	assert_true(fx.get_child(0) is AudioStreamPlayer3D)


func test_alarm_plays_once_within_the_cooldown() -> void:
	var fx := SoundEffects.new()
	add_child_autofree(fx)
	fx._on_alarm(Vector3.ZERO)
	fx._on_alarm(Vector3.ZERO)
	assert_eq(fx.get_child_count(), 1)
