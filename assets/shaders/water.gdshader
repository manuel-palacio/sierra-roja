shader_type spatial;
// The river in the gorge: green-brown water running downstream (+z), with pale streaks of
// current and broken light on it. Unshaded, with no screen or depth reads, so it costs next to
// nothing in the Compatibility renderer.
render_mode unshaded;

uniform vec3 deep : source_color = vec3(0.07, 0.17, 0.17);
uniform vec3 shallow : source_color = vec3(0.16, 0.30, 0.26);
uniform vec3 glint : source_color = vec3(0.80, 0.86, 0.84);
uniform float speed = 1.1;

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
	float broad = noise(vec2(world.x * 0.7, world.z * 0.22 - flow));
	float fine = noise(vec2(world.x * 2.6 + 3.0, world.z * 0.9 - flow * 1.8));
	float ripple = noise(vec2(world.x * 6.0 - flow * 0.3, world.z * 3.0 - flow * 2.6));
	vec3 colour = mix(deep, shallow, broad);
	float streak = smoothstep(0.58, 0.80, broad * 0.55 + fine * 0.45);
	float sparkle = smoothstep(0.80, 0.95, ripple) * smoothstep(0.35, 0.7, fine);
	ALBEDO = mix(colour, glint, streak * 0.45 + sparkle * 0.6);
}
