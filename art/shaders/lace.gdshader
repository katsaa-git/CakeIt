shader_type spatial;
// Sugar lace (lace trim round a tier): the decoration shader with holes.
// The lace pattern is cut from the texture coordinates the ribbon builder
// gives it (u along the trim in scallops, v from the top edge, 0, to the
// scalloped bottom edge, 1): a solid top band, a row of little flowers in
// each scallop over a fine diamond net, and a solid scalloped edge.
// Otherwise as decoration.gdshader. Vertex colour RGB is the base colour; vertex alpha says how
// much of it takes the piece's own colour, which comes per piece from the
// MultiMesh custom data:
//   rgb = colour, a = finish level (whole part, 0..15) + a random number per
//   piece (fractional part).
// Pieces built one by one bake their colour in, use alpha 0 and get their
// finish from `piece_shine`. Lustre dust comes from the tier's shimmer mask.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://art/shaders/shimmer.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
uniform float sss : hint_range(0.0, 1.0) = 0.0;
// Pearly, rainbow-tinted sheen at grazing angles (sugar pearls).
uniform float pearl : hint_range(0.0, 1.0) = 0.0;
// Soft, velvety glow at grazing angles (satin, peach fuzz).
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
// The finish of a piece built on its own (0 plain, 1 metallic).
instance uniform float piece_shine = 0.0;

varying vec4 custom;
varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 where the lace is solid, 0 where there is a hole.
float lace_solid(vec2 uv) {
	float v = uv.y;
	// A row of tiny eyelets along the top band.
	if (v < 0.13) {
		vec2 eye = vec2((fract(uv.x * 7.0) - 0.5) / 7.0, v - 0.07);
		return step(0.022, length(eye * vec2(1.0, 1.4)));
	}
	// The scalloped edge itself is solid.
	if (v > 0.88) {
		return 1.0;
	}
	// A little flower in every scallop, its middle pierced by a ring.
	vec2 c = (vec2(fract(uv.x), v) - vec2(0.5, 0.56)) * vec2(1.0, 1.3);
	float d = length(c);
	float petal_edge = 0.17 + 0.055 * cos(atan(c.y, c.x) * 6.0);
	float flower = step(d, petal_edge) * step(0.02, abs(d - 0.085));
	// A fine diamond net between the flowers.
	vec2 n = vec2(uv.x * 7.0, v * 5.5);
	vec2 g = abs(fract(vec2(n.x + n.y, n.x - n.y) * 0.5) - 0.5);
	float net = step(min(g.x, g.y), 0.07);
	// A thin solid line just above the scallops.
	float hem = step(0.8, v);
	return max(max(flower, net), hem);
}

void fragment() {
	if (lace_solid(UV) < 0.5) {
		discard;
	}
	if (!(dot(NORMAL, NORMAL) > 0.25)) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 base = srgb_to_linear(COLOR.rgb);
	vec3 tint = srgb_to_linear(custom.rgb);
	vec3 albedo = mix(base, base * tint, clamp(COLOR.a, 0.0, 1.0));
	float random_value = fract(custom.a);
	float shine = max(floor(custom.a + 0.0005) / 15.0, piece_shine);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (pearl > 0.0) {
		float f = pow(1.0 - facing, 2.0);
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (f * 0.8 + random_value + vec3(0.0, 0.33, 0.67)));
		albedo = mix(albedo, albedo * 0.6 + rainbow * 0.5, f * pearl);
	}
	float rough = roughness;
	float metal = metallic;
	float spec = specular_amount;
	apply_finish(shine, NORMAL, VIEW, albedo, rough, metal, spec);
	vec3 normal = NORMAL;
	mat3 view_from_cake = mat3(VIEW_MATRIX) * transpose(mat3(cake_from_world));
	apply_shimmer(shimmer_local(world_pos), view_from_cake, albedo, rough, metal, spec, normal);
	NORMAL = normal;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.08;
	SSS_STRENGTH = sss;
	RIM = sheen;
	RIM_TINT = 0.6;
}
