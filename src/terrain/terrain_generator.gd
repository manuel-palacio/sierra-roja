class_name TerrainGenerator
extends RefCounted
## Builds a HeightField from a TerrainSpec. The same spec always gives the same land.


static func build(spec: TerrainSpec) -> HeightField:
	var area := spec.bounds.grow(spec.skirt)
	var cols := int(ceilf(area.size.x / spec.cell)) + 1
	var rows := int(ceilf(area.size.y / spec.cell)) + 1
	var field := HeightField.new(area.position, spec.cell, cols, rows)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = spec.seed
	noise.frequency = 1.0 / maxf(spec.noise_period, 0.001)
	for r in rows:
		for c in cols:
			var p := Vector2(area.position.x + c * spec.cell, area.position.y + r * spec.cell)
			var h := spec.base_height
			if spec.noise_amplitude != 0.0:
				h += clampf(noise.get_noise_2d(p.x, p.y), -1.0, 1.0) * spec.noise_amplitude
			for feature in spec.features:
				var hit := _measure(feature, p)
				var strength := _strength(hit.x, feature)
				if strength <= 0.0:
					continue
				if feature.mode == TerrainFeature.Mode.ADD:
					h += feature.height * strength
				else:
					var target := feature.height
					if not is_nan(feature.end_height):
						target = lerpf(feature.height, feature.end_height, hit.y)
					h = lerpf(h, target, strength)
				if strength >= 1.0 and feature.surface >= 0:
					field.set_surface(c, r, feature.surface as HeightField.Surface)
			field.set_h(c, r, h)
	return field


## 1 inside the width, easing to 0 over the falloff.
static func _strength(distance: float, feature: TerrainFeature) -> float:
	if distance <= feature.width:
		return 1.0
	if feature.falloff <= 0.0:
		return 0.0
	return 1.0 - smoothstep(0.0, 1.0, (distance - feature.width) / feature.falloff)


## x: distance from the point to the feature. y: how far along a PATH the nearest point is, 0 to 1.
static func _measure(feature: TerrainFeature, p: Vector2) -> Vector2:
	var points := feature.points
	if points.is_empty():
		return Vector2(INF, 0.0)
	if feature.kind == TerrainFeature.Kind.MOUND or points.size() == 1:
		return Vector2(p.distance_to(points[0]), 0.0)
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var best := INF
	var best_along := 0.0
	var walked := 0.0
	for i in points.size() - 1:
		var nearest := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		var d := p.distance_to(nearest)
		if d < best:
			best = d
			best_along = walked + points[i].distance_to(nearest)
		walked += points[i].distance_to(points[i + 1])
	return Vector2(best, best_along / total if total > 0.0 else 0.0)
