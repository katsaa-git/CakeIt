shader_type spatial;
// The view through the bakery window: a bright pastel sky with soft clouds
// over a calm sea, and a little lighthouse on a headland. It glows, so the
// window lights the room and blooms gently; depth of field softens it.
render_mode unshaded, cull_disabled;

uniform vec3 sky_top : source_color = vec3(0.74, 0.86, 0.94);
uniform vec3 sky_low : source_color = vec3(1.0, 0.96, 0.92);
uniform vec3 sea_far : source_color = vec3(0.68, 0.85, 0.88);
uniform vec3 sea_near : source_color = vec3(0.56, 0.76, 0.82);
uniform vec3 land_color : source_color = vec3(0.68, 0.78, 0.62);
uniform float brightness = 1.7;
uniform float horizon = 0.42;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	float t = TIME * 0.004;
	vec3 color;
	if (uv.y > horizon) {
		float h = (uv.y - horizon) / (1.0 - horizon);
		color = mix(srgb_to_linear(sky_low), srgb_to_linear(sky_top), pow(h, 0.8));
		float cloud = texture(noise_tex, vec2(uv.x * 0.25 + t, uv.y * 0.5)).r;
		cloud = smoothstep(0.45, 0.85, cloud) * smoothstep(0.0, 0.4, h);
		color = mix(color, vec3(1.0, 0.99, 0.97), cloud * 0.55);
	} else {
		float d = (horizon - uv.y) / horizon;
		color = mix(srgb_to_linear(sea_far), srgb_to_linear(sea_near), d);
		float glint = texture(noise_tex, vec2(uv.x * 3.0 + t * 3.0, uv.y * 12.0)).r;
		color += vec3(smoothstep(0.7, 0.85, glint) * 0.25 * (1.0 - d));
	}
	// A green headland on the right with a lighthouse.
	float land_top = horizon + 0.07 * smoothstep(0.62, 0.9, uv.x) - 0.02 * smoothstep(0.9, 1.0, uv.x);
	if (uv.x > 0.6 && uv.y < land_top && uv.y > horizon - 0.04) {
		color = srgb_to_linear(land_color);
	}
	float lx = abs(uv.x - 0.8);
	if (lx < 0.012 && uv.y > land_top - 0.01 && uv.y < land_top + 0.11) {
		float stripe = step(0.5, fract((uv.y - land_top) * 28.0));
		color = mix(vec3(0.98, 0.97, 0.95), vec3(0.9, 0.45, 0.42), stripe);
	}
	// Unshaded: ALBEDO is the final colour. Above 1.0 it blooms softly.
	ALBEDO = color * brightness;
}
