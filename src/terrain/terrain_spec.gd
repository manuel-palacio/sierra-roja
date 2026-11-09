class_name TerrainSpec
extends Resource
## The authored description of a mission's land. TerrainGenerator turns it into a HeightField.

## Playable area on the ground plane (x, z).
@export var bounds := Rect2(-40.0, -30.0, 80.0, 60.0)
## Metres of land beyond the bounds on every side, so the camera never sees the map end.
@export var skirt := 45.0
@export var cell := 1.0
@export var base_height := 0.0
@export var seed := 1
## Metres of rolling noise either way. Applied before the features, so SET features stay exact.
@export var noise_amplitude := 0.0
## Metres between noise crests, roughly.
@export var noise_period := 24.0
@export var features: Array[TerrainFeature] = []
