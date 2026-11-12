extends GutTest
## Carchuna can be won with a player's orders against live guards without being noticed, and
## walking in by the gate is not the way.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const CarchunaBot := preload("res://tests/run/carchuna_bot.gd")

var _bot: CarchunaBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null


func test_stealth_play_wins() -> void:
	_bot = await CarchunaBot.start(self)
	await _bot.play()
	gut.p(_bot.summary())
	assert_eq(_bot.rules.result, MissionRules.Result.WON, _bot.summary())
	assert_lt(_bot.elapsed, CarchunaBot.CAP, "inside the cap")
	assert_false(_bot.noticed, "no guard left its patrol at any time")
	assert_eq(_bot.max_alarm, 0)
	assert_eq(_bot.dynamiter.hp, _bot.dynamiter.stats.max_hp, "the Dynamiter was never hit")
	assert_eq(_bot.marksman.hp, _bot.marksman.stats.max_hp, "nor the Marksman")
	assert_true(_bot.prisoner.alive)
	assert_eq(_bot.prisoner.hp, _bot.prisoner.stats.max_hp, "nor the officer")


func test_walking_in_by_the_gate_is_caught() -> void:
	_bot = await CarchunaBot.start(self)
	_bot.walk_in_by_the_gate()
	await _bot.wait_until(func() -> bool: return _bot.max_alarm > 0)
	assert_gt(_bot.max_alarm, 0, _bot.summary())
	assert_true(_bot.noticed)
