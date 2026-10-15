shader_type canvas_item;
// A soft, warm darkening toward the corners, like an old photograph.

uniform float strength = 0.22;
uniform vec3 tint : source_color = vec3(0.35, 0.22, 0.15);

void fragment() {
	vec2 centered = UV - 0.5;
	centered.x *= 1.25;
	float d = length(centered);
	float v = smoothstep(0.42, 0.9, d) * strength;
	COLOR = vec4(tint, v);
}
