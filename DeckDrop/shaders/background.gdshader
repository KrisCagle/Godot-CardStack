shader_type canvas_item;
// Subtle radial gradient — bluish near the focal point, deep navy at edges.
// Anchor focal point slightly above center so the eye sits where the play
// action lives (the grid).

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, vec2(0.5, 0.35));
	vec3 inner = vec3(0.10, 0.13, 0.20);
	vec3 outer = vec3(0.03, 0.04, 0.08);
	vec3 col = mix(inner, outer, smoothstep(0.0, 0.85, dist));
	COLOR = vec4(col, 1.0);
}
