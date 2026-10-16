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
	// Classic marble: stripes running one way, bent by layered noise, so veins
	// wander and branch but never close into rings. They fade in and out in
	// patches so the slab is mostly calm.
	vec2 uv = world_pos.xz * scale;
	uv = mat2(vec2(0.87, 0.5), vec2(-0.5, 0.87)) * uv;
	float turb = texture(noise_tex, uv * 0.9).r * 0.55 + texture(noise_tex, uv * 2.1 + 0.37).r * 0.3 + texture(noise_tex, uv * 4.7 + 0.71).r * 0.15;
	float stripes = abs(sin(uv.x * 40.0 + turb * 7.0));
	float patches = smoothstep(0.3, 0.75, texture(noise_tex, uv * 0.35 + 0.13).r);
	float main_vein = pow(1.0 - stripes, 30.0) * patches;
	float soft_vein = pow(1.0 - stripes, 4.0) * 0.06 * patches;
	float fine = abs(sin(uv.x * 97.0 + turb * 13.0 + 1.3));
	float fine_vein = pow(1.0 - fine, 60.0) * smoothstep(0.5, 0.8, texture(noise_tex, uv * 0.6 + 0.81).r) * 0.4;
	float vein = main_vein * 0.65 + soft_vein + fine_vein;
	float cloud = texture(noise_tex, uv * 0.6 + 0.5).r;
	vec3 base = srgb_to_linear(base_color) * (0.975 + 0.04 * cloud);
	ALBEDO = mix(base, srgb_to_linear(vein_color), clamp(vein, 0.0, 0.55));
	ROUGHNESS = 0.2 + 0.08 * cloud;
	SPECULAR = 0.55;
	CLEARCOAT = 0.3;
	CLEARCOAT_ROUGHNESS = 0.12;
}
