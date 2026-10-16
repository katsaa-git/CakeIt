shader_type spatial;
// A candle flame: a soft teardrop on a quad that always turns to face the
// camera (staying upright), flickering and swaying a little, bright enough
// to bloom. INSTANCE_CUSTOM.a gives every flame its own rhythm.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.78);
uniform vec3 edge_color : source_color = vec3(1.0, 0.55, 0.18);
uniform float intensity = 3.0;

varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.a;
	float t = TIME + seed * 31.0;
	float flicker = 1.0 + 0.1 * sin(t * 13.0) + 0.06 * sin(t * 23.0 + 1.3);
	float up = VERTEX.y + 0.5;
	VERTEX.y = (VERTEX.y + 0.5) * flicker - 0.5;
	VERTEX.x += sin(t * 5.0) * 0.08 * up * up;
	// Upright billboard: turn round the vertical axis to face the camera.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * scale.x, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(cross(right, vec3(0.0, 1.0, 0.0)) * scale.z, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float y = 1.0 - UV.y;
	float x = (UV.x - 0.5) * 2.0;
	// Widest low down, drawn out to a soft point at the top.
	float width = 0.62 * pow(sin(3.14159 * clamp(y * 0.9 + 0.06, 0.0, 1.0)), 0.7) * (1.0 - y * 0.55);
	float d = abs(x) / max(width, 0.001);
	float body = 1.0 - smoothstep(0.55, 1.0, d);
	float core = 1.0 - smoothstep(0.0, 0.6, d + (1.0 - y) * 0.3);
	float fade = smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.85, 1.0, y));
	vec3 color = mix(edge_color, core_color, core);
	ALBEDO = color * intensity;
	ALPHA = body * fade;
}
