extends GutTest
## The mission can be won with a player's orders against live guards.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")

var _bot: BridgeBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null


func test_stealth_play_wins() -> void:
	_bot = await BridgeBot.start(self)
	await _bot.play()
	assert_eq(_bot.rules.result, MissionRules.Result.WON, _bot.summary())
	assert_true(_bot.rules.bridge_destroyed, "the bridge is down")
	assert_lt(_bot.elapsed, BridgeBot.CAP, "inside the 5-minute cap")
	assert_true(_bot.knife_used, "a guard was knifed")
	assert_true(_bot.body_hidden, "the body was hidden")
	assert_false(_bot.alarm_seen, "no guard ever raised the alarm")
