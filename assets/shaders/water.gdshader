shader_type spatial;
// The river in the gorge: dark water with pale streaks drifting downstream (+z). Unshaded, with no
// screen or depth reads, so it costs next to nothing in the Compatibility renderer.
render_mode unshaded;

uniform vec3 deep : source_color = vec3(0.025, 0.06, 0.11);
uniform vec3 glint : source_color = vec3(0.42, 0.52, 0.70);
uniform float speed = 0.9;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float flow = TIME * speed;
	float broad = noise(vec2(world.x * 0.9, world.z * 0.3 - flow));
	float fine = noise(vec2(world.x * 2.3 + 3.0, world.z * 0.8 - flow * 1.7));
	float streak = smoothstep(0.60, 0.82, broad * 0.6 + fine * 0.4);
	ALBEDO = mix(deep, glint, streak * 0.5);
}
