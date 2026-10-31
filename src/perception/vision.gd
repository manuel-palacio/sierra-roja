class_name Vision
extends RefCounted
## Pure vision-cone rules: no scene tree, no physics. Distance and angle are measured on the
## ground plane; walls are handled separately by Perception.

enum Zone { NONE, FAR, NEAR }

const DEFAULTS_PATH := "res://resources/guard_vision.tres"

static var _defaults: GuardVision


static func defaults() -> GuardVision:
	if _defaults == null:
		_defaults = load(DEFAULTS_PATH) as GuardVision
	return _defaults


## far_range is explicit because it changes after an alarm; everything else comes from `tuning`
## (the shared guard_vision.tres when null). A crawling target is only seen in the near zone.
static func zone(eye: Vector3, forward: Vector3, target: Vector3, stance: Unit.Stance,
		far_range: float, tuning: GuardVision = null) -> Zone:
	var v := tuning if tuning != null else defaults()
	var flat_to := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	var flat_fwd := Vector3(forward.x, 0.0, forward.z)
	var dist := flat_to.length()
	if dist > far_range:
		return Zone.NONE
	if dist > 0.0001 and flat_fwd.length() > 0.0001:
		if rad_to_deg(flat_fwd.angle_to(flat_to)) > v.half_angle_deg:
			return Zone.NONE
	if dist <= v.near_range:
		return Zone.NEAR
	if stance == Unit.Stance.CRAWLING:
		return Zone.NONE
	return Zone.FAR
