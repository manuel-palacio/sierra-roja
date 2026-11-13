extends GutTest
## The Ebro can be won with the knife inside the clock, and is lost by a shot or by waiting.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const EbroBot := preload("res://tests/run/ebro_bot.gd")

var _bot: EbroBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null


func test_stealth_play_wins_inside_the_clock() -> void:
	_bot = await EbroBot.start(self)
	await _bot.play()
	gut.p(_bot.summary())
	assert_eq(_bot.rules.result, MissionRules.Result.WON, _bot.summary())
	assert_lt(_bot.silenced_at, 240.0, "all three down with a minute in hand")
	assert_eq(_bot.knifed, 3)
	assert_false(_bot.alarm_before_quiet, "no guard reached ALARM before the last sentry was down")
	assert_eq(_bot.dynamiter.hp, _bot.dynamiter.stats.max_hp, "the Dynamiter was never hit")
	assert_eq(_bot.marksman.hp, _bot.marksman.stats.max_hp, "nor the Marksman")


func test_shooting_the_first_sentry_loses_it() -> void:
	_bot = await EbroBot.start(self)
	await _bot.shoot_the_first_sentry()
	gut.p(_bot.summary())
	assert_true(_bot.shot_fired, "he had the shot")
	assert_eq(_bot.silence.sentries_left(), 2, "and it told")
	assert_eq(_bot.rules.result, MissionRules.Result.LOST)
	assert_eq(_bot.rules.loss_reason(), SilenceObjective.SHOT_TEXT)
	assert_lt(_bot.elapsed, 2.0, "at once: nobody has to come and look")


func test_doing_nothing_loses_it_to_the_clock() -> void:
	_bot = await EbroBot.start(self)
	_bot.dynamiter.set_stance(Unit.Stance.CRAWLING)
	_bot.marksman.set_stance(Unit.Stance.CRAWLING)
	await _bot.wait_until(func() -> bool: return false)
	assert_eq(_bot.rules.result, MissionRules.Result.LOST)
	assert_eq(_bot.rules.loss_reason(), SilenceObjective.TOO_LATE_TEXT)
	assert_almost_eq(_bot.elapsed, 300.0, 2.0)
