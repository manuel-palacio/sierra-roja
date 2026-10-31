class_name Stats
extends Resource
## Tuning values for one unit type. Lives in a .tres so balance changes need no code.

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var crawl_speed := 1.2
@export var max_hp := 100
## Radius in metres of the noise a running unit makes.
@export var run_noise_radius := 8.0
