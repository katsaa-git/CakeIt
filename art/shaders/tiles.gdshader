shader_type spatial;
// Glazed subway tiles with soft grout lines, for the backsplash.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 tile_color : source_color = vec3(0.96, 0.93, 0.87);
uniform vec3 grout_color : source_color = vec3(0.84, 0.8, 0.74);
uniform vec2 tile_size = vec2(1.5, 0.75);
uniform float grout = 0.035;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_pos.x, world_pos.y) / tile_size;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p) * tile_size;
	vec2 edge = min(f, tile_size - f);
	float d = min(edge.x, edge.y);
	float tile = smoothstep(grout * 0.5, grout, d);
	// Each tile slightly different, with a soft pillowy bevel.
	float variation = texture(noise_tex, cell * 0.137).r;
	float bevel = smoothstep(grout, grout * 3.0, d);
	ALBEDO = mix(srgb_to_linear(grout_color), srgb_to_linear(tile_color) * (0.96 + 0.06 * variation), tile);
	ROUGHNESS = mix(0.8, 0.12 + 0.06 * variation, tile);
	SPECULAR = 0.5;
	NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	// Pillow bevel: tilt normals near the tile edges.
	vec2 to_center = (tile_size * 0.5 - f) / tile_size;
	vec3 n = normalize(vec3(-to_center.x * (1.0 - bevel) * 1.5, to_center.y * (1.0 - bevel) * 1.5, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
}
