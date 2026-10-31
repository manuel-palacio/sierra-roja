extends Node
## Autoload. Anything that makes sound announces it here; guards listen.

signal noise_emitted(pos: Vector3, radius: float)


func emit_noise(pos: Vector3, radius: float) -> void:
	noise_emitted.emit(pos, radius)
