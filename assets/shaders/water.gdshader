shader_type spatial;
// The river in the gorge: green-brown water running downstream (+z), with pale streaks of
// current and broken light on it. Unshaded, with no screen or depth reads, so it costs next to
// nothing in the Compatibility renderer.
render_mode unshaded;

uniform vec3 deep : source_color = vec3(0.07, 0.17, 0.17);
uniform vec3 shallow : source_color = vec3(0.16, 0.30, 0.26);
uniform vec3 glint : source_color = vec3(0.80, 0.86, 0.84);
uniform float speed = 1.1;
// The middle of the river as a line of points (x, z), how many of them are used, and how far from
// that line the water meets the rock. Foam gathers along that edge.
uniform vec2 course[8];
uniform int course_points = 0;
uniform float half_width = 3.3;
uniform vec3 foam : source_color = vec3(0.86, 0.90, 0.88);

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

float from_course(vec2 p) {
	float best = 1000.0;
	for (int i = 0; i < course_points - 1; i++) {
		vec2 a = course[i];
		vec2 b = course[i + 1];
		float t = clamp(dot(p - a, b - a) / dot(b - a, b - a), 0.0, 1.0);
		best = min(best, distance(p, a + (b - a) * t));
	}
	return best;
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
	colour = mix(colour, glint, streak * 0.45 + sparkle * 0.6);
	if (course_points > 1) {
		// Darker in the deep middle, and a broken line of foam where the water runs along the rock.
		float out_from_middle = from_course(world.xz) / half_width;
		colour *= mix(0.82, 1.08, smoothstep(0.0, 0.9, out_from_middle));
		float lapping = noise(vec2(world.x * 1.7 + flow * 0.4, world.z * 1.1 - flow * 1.3));
		float edge = smoothstep(0.80, 1.0, out_from_middle + (lapping - 0.5) * 0.22);
		colour = mix(colour, foam, edge * (0.55 + 0.45 * fine));
	}
	ALBEDO = colour;
}
