extends GutTest
## The mission can be lost: being seen brings the alarm, and the alarm kills.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
## South face of the guard post.
const GUARD_POST := Vector3(-12.0, 0.0, -11.5)

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


func test_walking_at_the_guard_post_loses() -> void:
	_bot = await BridgeBot.start(self)
	_bot.dynamiter.move_to(GUARD_POST)
	await _assert_caught()


func test_upright_walk_gets_caught() -> void:
	_bot = await BridgeBot.start(self)
	_bot.walk_upright()
	await _assert_caught()
