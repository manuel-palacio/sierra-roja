shader_type spatial;
render_mode cull_disabled;
// Leaf sprites under snow: the sprite's own shape, its colour most of the way to white. A tint
// over the texture can only darken it, which is why this is not a StandardMaterial3D.

uniform sampler2D leaf : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.5, 0.6, 0.5);
uniform vec3 snow_tint : source_color = vec3(0.90, 0.93, 0.97);
uniform float snow = 0.7;

void fragment() {
	vec4 texel = texture(leaf, UV);
	// More snow on the lighter parts of the sprite, so the dark between the needles stays dark.
	float lying = snow * smoothstep(0.15, 0.6, max(texel.r, max(texel.g, texel.b)));
	ALBEDO = mix(texel.rgb * tint, snow_tint * 0.9, lying);
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
