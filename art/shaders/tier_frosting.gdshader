shader_type spatial;
// The frosted surface of a cake tier.
//  - Coated: smooth buttercream with soft spatula marks (long smears around
//    the sides, circular swirls on top). `smoothness` fades the marks.
//  - Naked (semi-naked cake): sponge and filling layers show through a thin,
//    scraped coat on the sides; the top stays frosted.
//  - A new coat spreads from the top centre down the sides (`sweep` 0 -> 1),
//    pushing a little ridge of frosting ahead of it.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 coat_color : source_color = vec3(1.0, 0.96, 0.89);
uniform vec3 prev_color : source_color = vec3(1.0, 0.96, 0.89);
uniform float coated : hint_range(0.0, 1.0) = 1.0;
uniform float prev_coated : hint_range(0.0, 1.0) = 1.0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.45;
uniform float prev_smoothness : hint_range(0.0, 1.0) = 0.45;
uniform float sweep : hint_range(0.0, 1.0) = 1.0;
uniform float tier_radius = 1.4;
uniform float tier_height = 1.1;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sponge_color : source_color = vec3(0.92, 0.76, 0.52);
uniform vec3 filling_color : source_color = vec3(0.99, 0.95, 0.88);
uniform float layers = 3.0;
uniform float seed = 0.0;
uniform sampler3D noise3d : repeat_enable, filter_linear_mipmap;

varying vec3 obj_pos;
varying vec3 obj_nrm;

vec3 srgb_to_linear(vec3 c) {
	// Clamp first: with MSAA, colours can be extrapolated slightly below zero at
	// triangle edges, and pow() of a negative number is NaN (black specks).
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float n3(vec3 p) {
	return texture(noise3d, p).r;
}

void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

// 0 at the top centre, about 0.35 at the top edge, 1 at the bottom of the side.
float spread_coord(vec3 p, float top_w) {
	float r = length(p.xz);
	float top = r / tier_radius * 0.35;
	float side = 0.35 + clamp((tier_height - p.y) / tier_height, 0.0, 1.0) * 0.65;
	return mix(side, top, top_w);
}

// Spatula marks: horizontal smears on the side, circular swirls on top.
float spatula(vec3 p, float ang, float r, float top_w, float smooth_amount) {
	float side_marks = n3(vec3(ang * tier_radius * 0.18, p.y * 1.6, seed));
	side_marks = side_marks * 0.7 + n3(vec3(ang * tier_radius * 0.5, p.y * 4.5, seed + 0.31)) * 0.3;
	float top_marks = n3(vec3(r * 1.9, ang * 0.35, seed + 0.62));
	top_marks = top_marks * 0.7 + n3(vec3(r * 5.0, ang * 1.1, seed + 0.83)) * 0.3;
	float marks = mix(side_marks, top_marks, top_w);
	return marks * (1.0 - smooth_amount);
}

void fragment() {
	// With MSAA a pixel can be shaded just outside a thin triangle, where the
	// blended normal can collapse to zero (NaN, black specks). Fall back to
	// the true face direction there.
	if (!(dot(NORMAL, NORMAL) > 0.25)) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 p = obj_pos;
	float ang = atan(p.z, p.x);
	float r = length(p.xz);
	float top_w = smoothstep(0.35, 0.85, obj_nrm.y);

	// Which coat is showing here, and the ridge at the spreading front.
	float coord = spread_coord(p, top_w);
	float wobble = (n3(vec3(ang * 0.5, p.y * 0.4, seed + 0.17)) - 0.5) * 0.06;
	float front = sweep * 1.12 - 0.04;
	float is_new = 1.0 - smoothstep(front - 0.015, front + 0.015, coord + wobble);
	float ridge = exp(-((coord + wobble - front) / 0.025) * ((coord + wobble - front) / 0.025)) * step(0.001, sweep) * (1.0 - step(0.999, sweep));

	vec3 color_now = mix(srgb_to_linear(prev_color), srgb_to_linear(coat_color), is_new);
	float coated_now = mix(prev_coated, coated, is_new);
	float smooth_now = mix(prev_smoothness, smoothness, is_new);

	// Surface height for bump: spatula marks plus the spreading ridge.
	float height = spatula(p, ang, r, top_w, smooth_now) * 0.6 + ridge * 1.2;

	// Semi-naked sides: sponge layers with filling between, under a scraped coat.
	float y01 = clamp(p.y / tier_height, 0.0, 1.0);
	float band = fract(y01 * layers);
	float filling = 1.0 - smoothstep(0.04, 0.085, min(band, 1.0 - band));
	filling *= step(0.08, y01) * step(y01, 0.92);
	float crumb = smoothstep(0.55, 0.75, n3(p * 3.1 + vec3(seed)));
	vec3 sponge = srgb_to_linear(sponge_color) * (1.0 - 0.18 * crumb);
	vec3 inside = mix(sponge, srgb_to_linear(filling_color), filling);
	float scrape = n3(vec3(ang * tier_radius * 0.22, p.y * 2.2, seed + 0.45));
	float frost_mask = smoothstep(0.42, 0.62, scrape + filling * 0.3 + smoothstep(0.85, 1.0, y01) * 0.6 + (1.0 - smoothstep(0.0, 0.08, y01)) * 0.4);
	frost_mask = max(frost_mask, top_w);
	vec3 naked = mix(inside, color_now, frost_mask);
	float naked_rough = mix(0.8, 0.5, frost_mask);

	vec3 albedo = mix(naked, color_now, coated_now);
	albedo *= 0.975 + 0.05 * n3(p * 0.35 + vec3(seed));
	height += (1.0 - coated_now) * (1.0 - frost_mask) * crumb * 0.8;

	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(height);
	float dhy = dFdy(height);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	vec3 bumped = abs(det) * NORMAL - grad * 0.012;
	float bumped_length = length(bumped);
	// Guard against zero-length normals (they turn into NaN and black squares).
	if (bumped_length > 1e-20 && abs(det) > 1e-24) {
		NORMAL = bumped / bumped_length;
	}

	ALBEDO = albedo;
	ROUGHNESS = mix(naked_rough, 0.46 - 0.08 * smooth_now, coated_now);
	SPECULAR = 0.42;
	SSS_STRENGTH = mix(0.12, 0.35, max(coated_now, frost_mask));
	RIM = 0.18;
	RIM_TINT = 0.7;
	EMISSION = albedo * highlight * 0.18;
}
