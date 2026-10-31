class_name AbilityKit
extends RefCounted
## Builds abilities from ids, so scenes and saves can name them as plain strings. Kept apart
## from Ability so the base class does not reference its own subclasses.

const ALL := ["knife", "charge", "pistol", "rifle", "carry"]


static func create(id: String, tuning: AbilityTuning = null) -> Ability:
	match id:
		"knife":
			return Knife.new(tuning)
		"charge":
			return Charge.new(tuning)
		"pistol":
			return Pistol.new(tuning)
		"rifle":
			return Rifle.new(tuning)
		"carry":
			return Carry.new(tuning)
	push_error("AbilityKit: unknown ability '%s'" % id)
	return null
