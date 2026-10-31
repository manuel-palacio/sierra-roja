class_name GuardTuning
extends Resource
## Timers and rifle numbers for guards. Lives in resources/guard_tuning.tres so balance needs
## no code. Vision ranges live in GuardVision.

const DEFAULTS_PATH := "res://resources/guard_tuning.tres"

static var _defaults: GuardTuning

## Seconds in the far zone, in total, before a suspicious guard raises the alarm.
@export var far_time_to_alarm := 1.5
## Seconds with no sight before a suspicious guard goes to the last position.
@export var suspicious_no_sight := 3.0
## Seconds a guard waits at the investigated spot, with no sight, before going back on patrol.
@export var investigate_wait := 4.0
## Seconds with no sight before an alarm stands down.
@export var alarm_stand_down := 30.0
@export var rifle_damage := 34
@export var fire_interval := 1.5
@export var fire_range := 14.0
## Seconds without moving stuck_progress metres before a guard counts as stuck.
@export var stuck_time := 3.0
@export var stuck_progress := 0.25
## Seconds between one guard's vision checks.
@export var vision_interval := 0.1


static func defaults() -> GuardTuning:
	if _defaults == null:
		_defaults = load(DEFAULTS_PATH) as GuardTuning
	return _defaults
