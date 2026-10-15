shader_type spatial;
// Warm white marble: a few soft, meandering grey-beige veins with gentle
// halos (ridges of low-frequency noise), polished but not mirror-like.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.95, 0.935, 0.91);
uniform vec3 vein_color : source_color = vec3(0.7, 0.66, 0.62);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float scale = 0.018;

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// A ridge where the noise crosses its middle: thin, wandering lines.
float ridge(vec2 uv) {
	float n = texture(noise_tex, uv).r;
	return 1.0 - abs(n - 0.5) * 2.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * scale;
	vec2 warp = vec2(texture(noise_tex, uv * 1.7 + 0.21).r, texture(noise_tex, uv * 1.7 + 0.67).r) - 0.5;
	uv += warp * 0.08;
	float main_vein = ridge(uv * vec2(1.0, 0.55));
	float fine_vein = ridge(uv * 2.6 + 0.37);
	float vein = pow(main_vein, 26.0) * 0.75 + pow(main_vein, 5.0) * 0.12 + pow(fine_vein, 40.0) * 0.35;
	float cloud = texture(noise_tex, uv * 0.6 + 0.5).r;
	vec3 base = srgb_to_linear(base_color) * (0.975 + 0.04 * cloud);
	ALBEDO = mix(base, srgb_to_linear(vein_color), clamp(vein, 0.0, 0.8));
	ROUGHNESS = 0.2 + 0.08 * cloud;
	SPECULAR = 0.55;
	CLEARCOAT = 0.3;
	CLEARCOAT_ROUGHNESS = 0.12;
}
