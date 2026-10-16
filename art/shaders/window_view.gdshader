shader_type spatial;
// The view through the bakery window: a soft pastel sky that warms to peach
// at a hazy horizon, big lazy clouds, a calm blue sea with a few sparkles
// near the horizon, and a little lighthouse on a green headland. It glows,
// so the window lights the room and blooms gently; depth of field softens it.
render_mode unshaded, cull_disabled;

uniform vec3 sky_top : source_color = vec3(0.72, 0.8, 0.92);
uniform vec3 sky_low : source_color = vec3(1.0, 0.92, 0.85);
uniform vec3 sea_far : source_color = vec3(0.7, 0.79, 0.87);
uniform vec3 sea_near : source_color = vec3(0.6, 0.71, 0.81);
uniform vec3 land_color : source_color = vec3(0.66, 0.75, 0.58);
uniform vec3 land_far_color : source_color = vec3(0.74, 0.8, 0.82);
uniform float brightness = 1.45;
uniform float horizon = 0.3;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float n(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec2 uv = UV;
	uv.y = 1.0 - uv.y;
	float t = TIME * 0.003;
	vec3 color;
	if (uv.y > horizon) {
		float h = (uv.y - horizon) / (1.0 - horizon);
		color = mix(srgb_to_linear(sky_low), srgb_to_linear(sky_top), smoothstep(0.0, 0.85, h));
		// Big soft clouds: low-frequency noise, flattened, with a brighter top
		// edge and a slightly warm-grey underside.
		vec2 cp = vec2(uv.x * 0.18 + t, uv.y * 0.42);
		float shape = n(cp) * 0.75 + n(cp * 2.3 + 0.31) * 0.25;
		float cloud = smoothstep(0.52, 0.72, shape) * smoothstep(0.05, 0.3, h) * (1.0 - smoothstep(0.8, 1.0, h) * 0.5);
		float lit = smoothstep(0.0, 0.08, shape - n(cp + vec2(0.0, -0.025)));
		vec3 cloud_color = mix(vec3(0.9, 0.88, 0.9), vec3(1.0, 0.98, 0.95), 0.6 + 0.4 * lit);
		color = mix(color, cloud_color, cloud * 0.8);
	} else {
		float d = (horizon - uv.y) / horizon;
		color = mix(srgb_to_linear(sea_far), srgb_to_linear(sea_near), pow(d, 0.7));
		// Gentle swell: faint horizontal bands.
		color *= 0.97 + 0.04 * n(vec2(uv.x * 0.6 + t, uv.y * 9.0));
		// A few sparkles, stretched sideways, mostly near the horizon.
		float glint = n(vec2(uv.x * 1.6 + t * 4.0, uv.y * 40.0));
		color += vec3(smoothstep(0.8, 0.9, glint) * 0.3 * pow(1.0 - d, 2.0));
	}
	// Haze where sea meets sky.
	float haze = exp(-abs(uv.y - horizon) * 22.0);
	color = mix(color, srgb_to_linear(sky_low), haze * 0.55);

	// A faint far coast on the left, then the green headland with the lighthouse on the right.
	float far_top = horizon + 0.018 * smoothstep(0.0, 0.25, uv.x) * (1.0 - smoothstep(0.25, 0.45, uv.x)) + 0.006 * n(vec2(uv.x * 2.0, 0.5));
	if (uv.x < 0.45 && uv.y < far_top && uv.y > horizon - 0.004) {
		color = mix(color, srgb_to_linear(land_far_color), 0.7);
	}
	float land_top = horizon + 0.07 * smoothstep(0.62, 0.9, uv.x) - 0.02 * smoothstep(0.9, 1.0, uv.x) + 0.008 * n(vec2(uv.x * 3.0, 0.2));
	if (uv.x > 0.6 && uv.y < land_top && uv.y > horizon - 0.04) {
		float shade = 0.9 + 0.12 * n(vec2(uv.x * 6.0, uv.y * 6.0));
		color = srgb_to_linear(land_color) * shade;
	}
	float lx = abs(uv.x - 0.8);
	if (lx < 0.012 && uv.y > land_top - 0.01 && uv.y < land_top + 0.11) {
		float stripe = step(0.5, fract((uv.y - land_top) * 28.0));
		color = mix(vec3(0.98, 0.97, 0.95), vec3(0.88, 0.48, 0.45), stripe);
	}
	// Unshaded: ALBEDO is the final colour. Above 1.0 it blooms softly.
	ALBEDO = color * brightness;
}
