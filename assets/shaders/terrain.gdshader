shader_type spatial;
// The land: four ground textures blended by per-vertex weights (grass, dry earth, road, ballast),
// rock on steep faces and wherever no ground weight is given, and a fade into mist past the edge
// of the playable map. Textures are laid out in world space, so they run on across chunks.

uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ballast : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The relief of each ground texture, so the low sun picks out tufts, stones and ruts.
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float relief = 0.65;
// Cloud shadows drifting over the land: how dark, how big (metres), how fast (metres a second).
uniform float cloud_shade = 0.24;
uniform float cloud_size = 55.0;
uniform vec2 cloud_drift = vec2(1.6, 0.7);
// Texture repeats per metre.
uniform float ground_tiling = 0.21;
uniform float rock_tiling = 0.13;
uniform vec3 ballast_tint : source_color = vec3(0.62, 0.58, 0.54);
// The playable rectangle (x0, z0, x1, z1) and how far beyond it the land takes to vanish.
uniform vec4 bounds = vec4(-40.0, -30.0, 40.0, 30.0);
uniform float fade_distance = 30.0;
uniform vec3 mist : source_color = vec3(0.5, 0.55, 0.6);

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 weights;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	weights = COLOR;
}

void fragment() {
	vec2 uv = world_position.xz * ground_tiling;
	// A slow change of tone across the land, so the tiling does not show from above.
	float broad = texture(earth, world_position.xz * 0.011).r;
	float tone = mix(0.82, 1.14, smoothstep(0.25, 0.75, broad));
	vec3 flat_colour = texture(grass, uv).rgb * weights.r * tone
			+ texture(earth, uv * 0.9).rgb * weights.g * tone
			+ texture(road, uv * 1.3).rgb * weights.b
			+ texture(ballast, uv * 1.6).rgb * ballast_tint * weights.a;
	float ground = weights.r + weights.g + weights.b + weights.a;
	flat_colour /= max(ground, 0.001);

	// Rock is projected from the sides as well as from above, so cliffs are not smeared.
	vec3 n = normalize(world_normal);
	vec3 facing = abs(n);
	facing.y *= 0.6;
	facing /= facing.x + facing.y + facing.z;
	vec3 rock_colour = texture(rock, world_position.zy * rock_tiling).rgb * facing.x
			+ texture(rock, world_position.xz * rock_tiling).rgb * facing.y
			+ texture(rock, world_position.xy * rock_tiling).rgb * facing.z;
	// Rock from about 45 degrees; fully rock by 58. Banks a unit cannot climb but that are not
	// cliffs (the railway embankment) stay earth and grass.
	float steep = smoothstep(0.71, 0.53, n.y);
	float rock_weight = max(steep, 1.0 - clamp(ground, 0.0, 1.0));
	vec3 colour = mix(flat_colour, rock_colour * 0.9, rock_weight);

	// Relief: the textures' own normal maps, laid on the ground plane and blended like the colours.
	vec2 bump = (texture(grass_normal, uv).xy * 2.0 - 1.0) * weights.r
			+ (texture(earth_normal, uv * 0.9).xy * 2.0 - 1.0) * weights.g
			+ (texture(road_normal, uv * 1.3).xy * 2.0 - 1.0) * (weights.b + weights.a);
	bump /= max(ground, 0.001);
	vec2 rock_bump = texture(rock_normal, world_position.xz * rock_tiling).xy * 2.0 - 1.0;
	bump = mix(bump, rock_bump * 1.4, rock_weight) * relief;
	vec3 bumped = normalize(n + vec3(bump.x, 0.0, -bump.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);

	vec2 sky = (world_position.xz + cloud_drift * TIME) / cloud_size;
	float cloud = value_noise(sky) * 0.65 + value_noise(sky * 2.3 + 7.0) * 0.35;
	colour *= 1.0 - cloud_shade * smoothstep(0.48, 0.70, cloud);

	vec2 outside = max(max(bounds.xy - world_position.xz, world_position.xz - bounds.zw), vec2(0.0));
	float fade = smoothstep(0.0, fade_distance, length(outside));
	ALBEDO = colour * (1.0 - fade);
	EMISSION = mist * fade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
