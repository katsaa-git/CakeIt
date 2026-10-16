shader_type spatial;
// Decorations. Vertex colour RGB is the base colour; vertex alpha says how
// much of it takes the piece's own colour, which comes per piece from the
// MultiMesh custom data (rgb = colour, a = a random number per piece).
// Pieces built one by one bake their colour in and use alpha 0.
render_mode diffuse_burley, specular_schlick_ggx;

uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
uniform float sss : hint_range(0.0, 1.0) = 0.0;
// Pearly, rainbow-tinted sheen at grazing angles (sugar pearls).
uniform float pearl : hint_range(0.0, 1.0) = 0.0;

varying vec4 custom;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	if (!(dot(NORMAL, NORMAL) > 0.25)) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 base = srgb_to_linear(COLOR.rgb);
	vec3 tint = srgb_to_linear(custom.rgb);
	vec3 albedo = mix(base, base * tint, clamp(COLOR.a, 0.0, 1.0));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	if (pearl > 0.0) {
		float f = pow(1.0 - facing, 2.0);
		vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (f * 0.8 + custom.a + vec3(0.0, 0.33, 0.67)));
		albedo = mix(albedo, albedo * 0.6 + rainbow * 0.5, f * pearl);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular_amount;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.08;
	SSS_STRENGTH = sss;
}
