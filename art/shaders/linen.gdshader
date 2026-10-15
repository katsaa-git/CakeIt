shader_type spatial;
// A woven linen tea towel with two stripes near each edge.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 cloth_color : source_color = vec3(0.97, 0.95, 0.91);
uniform vec3 stripe_color : source_color = vec3(0.86, 0.62, 0.64);
uniform float weave_scale = 220.0;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec2 uv = UV;
	// Weave: alternating over-under threads.
	vec2 w = uv * weave_scale;
	float warp = sin(w.x * 3.14159) * 0.5 + 0.5;
	float weft = sin(w.y * 3.14159) * 0.5 + 0.5;
	float checker = step(0.5, fract((floor(w.x) + floor(w.y)) * 0.5));
	float thread = mix(warp, weft, checker);
	// Stripes running along both edges.
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float stripe = step(0.06, edge) * (1.0 - step(0.085, edge)) + step(0.1, edge) * (1.0 - step(0.115, edge));
	vec3 color = mix(srgb_to_linear(cloth_color), srgb_to_linear(stripe_color), stripe);
	ALBEDO = color * (0.965 + 0.035 * thread);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	SSS_STRENGTH = 0.15;
}
