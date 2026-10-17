// Shared by the tier frosting, piping and decoration shaders:
//  - the metallic finish (gold paint, pearl), stored per item as `shine`;
//  - lustre dust, painted with the dust brush into each tier's shimmer mask.
//
// The mask is wrapped round the tier like a label: u goes round (the angle),
// v goes up the side (0 to 0.5) and then in across the top to the middle
// (0.5 to 1). Anything near the tier (coat, piping, decorations) looks up
// the dust at its own position, so one brush stroke dusts everything under
// it. The GDScript twin of `shimmer_uv` is ShimmerMask.uv_of.

// World to cake frame (the turntable's spin undone), set once per frame.
global uniform mat4 cake_from_world;
// Premultiplied dust colour (linear rgb * amount) and amount.
uniform sampler2D shimmer_mask : filter_linear, repeat_enable;
// x radius, y height, z height of the tier's bottom in the cake frame,
// w 1 when this tier has any dust at all.
uniform vec4 shimmer_tier = vec4(1.0, 1.0, 0.0, 0.0);

// Position in the tier's own frame (origin at the middle of its bottom).
vec3 shimmer_local(vec3 world_position) {
	return (cake_from_world * vec4(world_position, 1.0)).xyz - vec3(0.0, shimmer_tier.z, 0.0);
}

vec2 shimmer_uv(vec3 p) {
	float r = length(p.xz);
	float u = atan(p.z, p.x) / 6.2831853 + 0.5;
	float side_gap = shimmer_tier.x - r;
	float top_gap = shimmer_tier.y - p.y;
	float v;
	if (top_gap < side_gap) {
		v = 0.5 + 0.5 * clamp(side_gap / shimmer_tier.x, 0.0, 1.0);
	} else {
		v = 0.5 * clamp(p.y / shimmer_tier.y, 0.0, 1.0);
	}
	// Keep clear of the wrap between the very middle of the top and the bottom.
	return vec2(u, clamp(v, 0.004, 0.996));
}

vec4 shimmer_hash(vec3 p) {
	vec4 q = fract(vec4(p.xyzx) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}

// The metallic finish: 1 is gold leaf or silver paint, about 0.5 pearl.
void apply_finish(float shine, vec3 normal, vec3 view, inout vec3 albedo, inout float rough, inout float metal, inout float spec) {
	if (shine <= 0.004) {
		return;
	}
	float metal_amount = smoothstep(0.55, 0.95, shine);
	float pearl_amount = shine * (1.0 - metal_amount);
	metal = mix(metal, 1.0, metal_amount);
	rough = mix(rough, 0.26, max(metal_amount, pearl_amount * 0.7));
	spec = mix(spec, 0.75, shine);
	float f = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 2.0);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (f * 0.7 + vec3(0.0, 0.33, 0.67)));
	albedo = mix(albedo, albedo * 0.72 + rainbow * 0.32, f * pearl_amount);
}

// Lustre dust at `local` (tier frame). A soft pearly sheen in the dust
// colour, and fine flakes, each a tiny tilted mirror, that catch the light
// one by one as the cake turns. Flakes are about half a millimetre and fade
// out when they would be smaller than a pixel, so they never fizz.
void apply_shimmer(vec3 local, mat3 view_from_cake, inout vec3 albedo, inout float rough, inout float metal, inout float spec, inout vec3 normal) {
	if (shimmer_tier.w < 0.5) {
		return;
	}
	vec4 dust = texture(shimmer_mask, shimmer_uv(local));
	float amount = dust.a;
	if (amount < 0.006) {
		return;
	}
	vec3 dust_color = dust.rgb / amount;
	float cover = smoothstep(0.0, 0.85, amount);
	albedo = mix(albedo, dust_color, cover * 0.5);
	metal = mix(metal, 0.85, cover * 0.55);
	rough = mix(rough, 0.3, cover * 0.65);
	spec = mix(spec, 0.7, cover);
	const float CELLS = 210.0;
	vec3 cell = floor(local * CELLS);
	vec4 h = shimmer_hash(cell);
	float pixel = length(fwidth(local)) * CELLS;
	float visible = 1.0 - smoothstep(0.7, 1.6, pixel);
	if (h.x < cover * 0.45 * visible) {
		vec3 tilt = normalize(shimmer_hash(cell + 17.0).xyz * 2.0 - 1.0);
		normal = normalize(normal + view_from_cake * tilt * 0.7);
		albedo = mix(albedo, dust_color, 0.85);
		metal = 1.0;
		rough = 0.08;
	}
}
