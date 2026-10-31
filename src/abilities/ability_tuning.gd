class_name AbilityTuning
extends Resource
## Ranges, shots, damage and noise for the specialist abilities. Lives in
## resources/ability_tuning.tres so balance needs no code.

const DEFAULTS_PATH := "res://resources/ability_tuning.tres"

static var _defaults: AbilityTuning

@export var knife_range := 1.5
@export var knife_damage := 100
@export var pickup_range := 1.5
@export var plant_range := 2.0
## Seconds from planting to the blast.
@export var charge_fuse := 10.0
@export var blast_radius := 8.0
@export var blast_noise_radius := 80.0
## Lethal for anything with normal hit points.
@export var blast_damage := 1000
@export var rifle_ammo := 5
@export var pistol_ammo := 8
@export var rifle_range := 40.0
@export var pistol_range := 15.0
@export var rifle_damage := 100
@export var pistol_damage := 50
@export var rifle_noise_radius := 35.0
@export var pistol_noise_radius := 20.0
## Heights of the line-of-sight ray for shots and knife blows: from the shooter's shoulder
## to the target's chest, so a 1 m wall does not stop a shot but a full wall does.
@export var shot_origin_height := 1.5
@export var shot_target_height := 1.0


static func defaults() -> AbilityTuning:
	if _defaults == null:
		_defaults = load(DEFAULTS_PATH) as AbilityTuning
	return _defaults
