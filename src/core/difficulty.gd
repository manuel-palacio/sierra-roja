class_name Difficulty
extends RefCounted
## How sharp the guards are: Easy, Normal (the numbers in resources/guard_tuning.tres and
## guard_vision.tres as they stand) or Hard. The level scales those shared numbers, so it takes
## hold at once for every guard that uses them. Chosen on the briefing and kept in the browser.
##
## Hard changes no distance, only times and wounds: a way that keeps out of every cone on Normal
## keeps out of it on Hard.

enum Level { EASY, NORMAL, HARD }

const NAMES := { Level.EASY: "Easy", Level.NORMAL: "Normal", Level.HARD: "Hard" }
const STORAGE_KEY := "sierra-roja-difficulty"
## Level -> what each number is multiplied by.
const FACTORS := {
	Level.EASY: { "far_time_to_alarm": 1.6, "rifle_damage": 0.75, "far_range": 0.85, "alarm_far_range": 0.85 },
	Level.NORMAL: {},
	Level.HARD: { "far_time_to_alarm": 0.65, "rifle_damage": 1.5, "alarm_stand_down": 1.5 },
}

static var level := Level.NORMAL
static var _restored := false
static var _base_tuning: GuardTuning
static var _base_vision: GuardVision


static func choose(value: Level) -> void:
	level = value
	apply()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{localStorage.setItem('%s','%d')}catch(e){}})()"
				% [STORAGE_KEY, int(value)], true)


## The level after this one, round again from Hard to Easy.
static func next() -> Level:
	return ((int(level) + 1) % Level.size()) as Level


## Once in a session: the level chosen before, where a browser kept it.
static func restore() -> void:
	if _restored:
		return
	_restored = true
	if OS.has_feature("web"):
		var kept := str(JavaScriptBridge.eval(
				"(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % STORAGE_KEY, true))
		if kept.is_valid_int() and int(kept) >= 0 and int(kept) < Level.size():
			level = int(kept) as Level
	apply()


## Sets the shared guard numbers to what the level makes of them.
static func apply() -> void:
	if _base_tuning == null:
		_base_tuning = GuardTuning.defaults().duplicate() as GuardTuning
		_base_vision = Vision.defaults().duplicate() as GuardVision
	var factors: Dictionary = FACTORS[level]
	var tuning := GuardTuning.defaults()
	for key in ["far_time_to_alarm", "alarm_stand_down"]:
		tuning.set(key, float(_base_tuning.get(key)) * float(factors.get(key, 1.0)))
	tuning.rifle_damage = roundi(_base_tuning.rifle_damage * float(factors.get("rifle_damage", 1.0)))
	var vision := Vision.defaults()
	for key in ["far_range", "alarm_far_range"]:
		vision.set(key, float(_base_vision.get(key)) * float(factors.get(key, 1.0)))
