shader_type canvas_item;
// Darkens the corners of the view a little, which draws the eye to the middle.

uniform float strength = 0.38;

void fragment() {
	vec2 from_centre = (UV - 0.5) * vec2(1.15, 1.0);
	float edge = smoothstep(0.38, 0.80, length(from_centre));
	COLOR = vec4(0.02, 0.02, 0.04, edge * strength);
}
