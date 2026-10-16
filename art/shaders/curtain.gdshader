shader_type spatial;
// A sheer linen café curtain, tied back with a ribbon: irregular soft folds
// that get deeper toward the hem, the lower half gathered toward the window
// frame in a gentle curve, a very slow sway, and window light glowing through.
//
// The mesh is a flat plane (FACE_Z) of `panel_size`; UV.y = 0 at the rail.
render_mode diffuse_burley, cull_disabled, depth_draw_opaque;

uniform vec3 cloth_color : source_color = vec3(0.98, 0.95, 0.9);
uniform vec3 ribbon_color : source_color = vec3(0.86, 0.58, 0.6);
uniform vec2 panel_size = vec2(2.4, 11.6);
// +1 when the curtain's outer edge (the side it is tied toward) is +x.
uniform float outer_side = 1.0;
uniform float folds = 6.0;
uniform float fold_depth = 0.16;
uniform float sway = 0.05;
uniform float opacity = 0.62;
// Where the ribbon ties the curtain back (0 = rail, 1 = hem), and how much
// of its width is left there.
uniform float tie_at = 0.62;
uniform float tie_width = 0.38;

varying float fold_shade;
varying float hang;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// How much of the panel's width is left at this height: full at the rail,
// pinched at the tie, flaring out a little below it.
float squeeze(float h) {
	float down = smoothstep(0.05, tie_at, h);
	float below = smoothstep(tie_at, 1.0, h);
	return mix(1.0, tie_width, down) + below * 0.22;
}

// Folds: two waves at unrelated frequencies so no two pleats look the same.
float wave(float u, float h, float time) {
	float p = u * folds * 6.2832;
	float drift = sin(time * 0.33 + u * 2.0) * 0.35 * h;
	return sin(p + drift) * 0.72 + sin(p * 0.47 + 1.9 + drift) * 0.28;
}

vec3 drape(vec2 uv, float time) {
	float h = uv.y;
	float outer_u = outer_side > 0.0 ? 1.0 : 0.0;
	float outer_x = (outer_u - 0.5) * panel_size.x;
	float x = (uv.x - 0.5) * panel_size.x;
	float s = squeeze(h);
	x = outer_x + (x - outer_x) * s;
	// Gathered fabric bunches into deeper folds.
	float depth = fold_depth * (0.45 + 0.55 * h) / max(s, 0.3);
	float z = wave(uv.x, h, time) * depth;
	z += sin(time * 0.5 + uv.x * 3.0) * sway * h * h;
	// The gathered part bellies out a little toward the room.
	z += (1.0 - s) * 0.25;
	return vec3(x, (0.5 - h) * panel_size.y, z);
}

void vertex() {
	vec2 e = vec2(0.004, 0.0);
	vec3 p = drape(UV, TIME);
	vec3 du = drape(UV + e.xy, TIME) - p;
	vec3 dv = drape(UV + e.yx, TIME) - p;
	VERTEX = p;
	NORMAL = normalize(cross(dv, du));
	fold_shade = wave(UV.x, UV.y, TIME);
	hang = UV.y;
}

void fragment() {
	vec3 base = srgb_to_linear(cloth_color);
	// Light gathers in the hollows of the folds.
	base *= 0.9 + 0.1 * fold_shade;
	float ribbon = smoothstep(0.009, 0.004, abs(hang - tie_at));
	// A slightly denser hem band.
	float hem = smoothstep(0.975, 0.985, hang);
	ALBEDO = mix(base, srgb_to_linear(ribbon_color), ribbon);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.85, 0.8, 0.72) * (1.0 - ribbon);
	ALPHA = mix(opacity, 0.92, max(ribbon, hem * 0.6));
}
