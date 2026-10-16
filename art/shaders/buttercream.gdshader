shader_type spatial;
// Piped buttercream. The colour comes from the mesh's vertex colours (sRGB),
// already darkened in the grooves of star tips. On top of that: a satin
// sheen, soft subsurface glow, and a faint "just piped" surface texture so
// the frosting never looks like smooth plastic.
render_mode diffuse_burley, specular_schlick_ggx;

uniform float roughness : hint_range(0.0, 1.0) = 0.44;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.42;
uniform float sss : hint_range(0.0, 1.0) = 0.18;
uniform float sheen : hint_range(0.0, 1.0) = 0.06;
// Tiny surface ripples.
uniform float bump_strength : hint_range(0.0, 4.0) = 0.75;
uniform float bump_scale = 2.4;
uniform sampler3D noise3d : repeat_enable, filter_linear_mipmap;
// Multiplies the final colour.
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 obj_pos;

vec3 srgb_to_linear(vec3 c) {
	// Clamp first: with MSAA, colours can be extrapolated slightly below zero at
	// triangle edges, and pow() of a negative number is NaN (black specks).
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	// With MSAA a pixel can be shaded just outside a thin triangle, where the
	// blended normal can collapse to zero (NaN, black specks). Fall back to
	// the true face direction there.
	if (!(dot(NORMAL, NORMAL) > 0.25)) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	vec3 base = srgb_to_linear(COLOR.rgb) * tint.rgb;
	float h = texture(noise3d, obj_pos * bump_scale).r;
	float fine = texture(noise3d, obj_pos * bump_scale * 4.1 + vec3(0.37)).r;
	float height = h * 0.8 + fine * 0.2;

	// Bump from screen-space derivatives (no tangents needed).
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(height);
	float dhy = dFdy(height);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	// Fade the ripples out toward the silhouette: there the screen-space
	// derivatives get huge and would make the edges sparkle.
	float facing = smoothstep(0.08, 0.45, abs(dot(NORMAL, VIEW)));
	vec3 bumped = abs(det) * NORMAL - grad * bump_strength * 0.004 * facing;
	float bumped_length = length(bumped);
	// Guard against zero-length normals (they turn into NaN and black squares).
	if (bumped_length > 1e-20 && abs(det) > 1e-24) {
		NORMAL = bumped / bumped_length;
	}

	ALBEDO = base * (0.97 + 0.06 * h);
	ROUGHNESS = roughness - 0.06 * fine;
	SPECULAR = specular_amount;
	SSS_STRENGTH = sss;
	RIM = sheen;
	RIM_TINT = 0.7;
}
