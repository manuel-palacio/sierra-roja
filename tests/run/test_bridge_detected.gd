extends GutTest
## The mission can be lost: being seen brings the alarm, and the alarm kills.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
## The yard in front of the checkpoint hut.
const CHECKPOINT_YARD := Vector3(-33.0, -3.0, 13.0)

var _bot: BridgeBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null


func _assert_caught() -> void:
	await _bot.wait_until(func() -> bool: return false)
	assert_true(_bot.alarm_seen, "a guard reached ALARM")
	assert_eq(_bot.rules.result, MissionRules.Result.LOST, _bot.summary())
	assert_lt(_bot.elapsed, BridgeBot.CAP, "inside the 5-minute cap")


func test_walking_into_the_checkpoint_loses() -> void:
	_bot = await BridgeBot.start(self)
	_bot.dynamiter.move_to(CHECKPOINT_YARD)
	await _assert_caught()


func test_upright_walk_gets_caught() -> void:
	_bot = await BridgeBot.start(self)
	_bot.walk_upright()
	await _assert_caught()
