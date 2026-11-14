class_name MissionScore
extends RefCounted
## How a mission went: the time it took, the guards killed, the alarms raised and the quick loads
## used, and the name that earns. MissionRules keeps one as the mission is played.

enum Rating { DONE, UNSEEN, GHOST }

## What each rating is called on the end screen and the briefing.
const RATING_NAMES := { Rating.DONE: "Done", Rating.UNSEEN: "Unseen", Rating.GHOST: "Ghost" }

var seconds := 0.0
var kills := 0
var alarms := 0
var loads := 0


## Ghost: no alarm and nobody killed. Unseen: no alarm.
func rating() -> Rating:
	if alarms > 0:
		return Rating.DONE
	return Rating.GHOST if kills == 0 else Rating.UNSEEN


## Better than [param other]: a higher rating, or the same in less time.
func beats(other: MissionScore) -> bool:
	if other == null or rating() != other.rating():
		return other == null or rating() > other.rating()
	return seconds < other.seconds


## "4:07"
static func clock(time: float) -> String:
	var whole := int(time)
	return "%d:%02d" % [whole / 60, whole % 60]


## JSON-safe.
func to_dict() -> Dictionary:
	return { "seconds": seconds, "kills": kills, "alarms": alarms, "loads": loads }


## Null unless [param d] is what to_dict makes.
static func from_dict(d: Variant) -> MissionScore:
	if not d is Dictionary:
		return null
	var score := MissionScore.new()
	for key in ["seconds", "kills", "alarms", "loads"]:
		var value: Variant = d.get(key)
		if not (value is float or value is int) or value < 0:
			return null
		score.set(key, float(value) if key == "seconds" else int(value))
	return score
