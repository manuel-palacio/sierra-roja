extends GutTest
## Krasny Bor can be won with a player's orders against live guards, unseen until the store goes
## up, and walking up to the guns is not the way.

const BridgeBot := preload("res://tests/run/bridge_bot.gd")
const KrasnyBorBot := preload("res://tests/run/krasny_bor_bot.gd")

var _bot: KrasnyBorBot
var _clock := BridgeBot.FastClock.new()


func before_each() -> void:
	_clock.engage()


func after_each() -> void:
	_clock.release()
	if _bot != null:
		_bot.finish()
		_bot = null
	for c in get_tree().get_nodes_in_group(PlantedCharge.GROUP):
		c.free()


func test_stealth_play_wins() -> void:
	_bot = await KrasnyBorBot.start(self)
	await _bot.play()
	gut.p(_bot.summary())
	assert_eq(_bot.rules.result, MissionRules.Result.WON, _bot.summary())
	assert_lt(_bot.elapsed, KrasnyBorBot.CAP, "inside the cap")
	assert_eq(_bot.lines_cut, 3)
	assert_true(_bot.charge_planted)
	assert_false(_bot.noticed_before_blast, "no guard left its patrol before the store went up")
	assert_eq(_bot.dynamiter.hp, _bot.dynamiter.stats.max_hp, "the Dynamiter was never hit")
	assert_eq(_bot.marksman.hp, _bot.marksman.stats.max_hp, "nor the Marksman")


func test_walking_up_to_the_guns_is_caught() -> void:
	_bot = await KrasnyBorBot.start(self)
	_bot.walk_up_to_the_guns()
	await _bot.wait_until(func() -> bool: return _bot.max_alarm > 0)
	assert_gt(_bot.max_alarm, 0, _bot.summary())
