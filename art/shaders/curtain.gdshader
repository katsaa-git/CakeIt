shader_type spatial;
// A sheer linen curtain: soft vertical folds that sway very slowly, and light
// glowing through it from the window behind.
render_mode diffuse_burley, cull_disabled, depth_draw_opaque;

uniform vec3 cloth_color : source_color = vec3(0.98, 0.95, 0.9);
uniform float folds = 7.0;
uniform float fold_depth = 0.22;
uniform float sway = 0.06;
uniform float opacity = 0.82;

varying float fold_shade;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	// UV.y = 0 at the top rail, 1 at the hem.
	float phase = UV.x * folds * 6.2832;
	float hang = UV.y;
	float wave = sin(phase + sin(TIME * 0.35 + UV.x * 2.0) * 0.4 * hang);
	VERTEX.z += wave * fold_depth * (0.6 + 0.4 * hang) + sin(TIME * 0.5 + UV.x * 3.0) * sway * hang * hang;
	float dwave = cos(phase) * fold_depth * folds * 6.2832;
	NORMAL = normalize(vec3(-dwave * 0.15, 0.0, 1.0));
	fold_shade = wave;
}

void fragment() {
	vec3 base = srgb_to_linear(cloth_color);
	ALBEDO = base * (0.92 + 0.08 * fold_shade);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.8, 0.75, 0.68);
	ALPHA = opacity;
}
