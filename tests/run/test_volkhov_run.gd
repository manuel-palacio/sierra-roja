extends GutTest
## The Volkhov can be won with a player's orders against live guards without being noticed, and
## walking over the open ice is not the way.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const VolkhovBot := preload("res://tests/run/volkhov_bot.gd")

var _bot: VolkhovBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null


func test_stealth_play_wins() -> void:
	_bot = await VolkhovBot.start(self)
	await _bot.play()
	gut.p(_bot.summary())
	assert_eq(_bot.rules.result, MissionRules.Result.WON, _bot.summary())
	assert_lt(_bot.elapsed, VolkhovBot.CAP, "inside the cap")
	assert_false(_bot.noticed, "no guard left its patrol at any time")
	assert_eq(_bot.max_alarm, 0)
	assert_eq(_bot.dynamiter.hp, _bot.dynamiter.stats.max_hp, "the Dynamiter was never hit")
	assert_eq(_bot.marksman.hp, _bot.marksman.stats.max_hp, "nor the Marksman")
	assert_true(_bot.orders_taken)
	assert_eq(_bot.item.carrier, _bot.dynamiter, "and he has them still")


func test_walking_across_the_ice_is_caught() -> void:
	_bot = await VolkhovBot.start(self)
	_bot.walk_over_the_open_ice()
	await _bot.wait_until(func() -> bool: return _bot.max_alarm > 0)
	assert_gt(_bot.max_alarm, 0, _bot.summary())
	assert_true(_bot.noticed)
