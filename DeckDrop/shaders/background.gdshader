shader_type canvas_item;
// Casino-table background: subtle radial gradient with a slow breathing pulse,
// plus a very faint scrolling diamond pattern overlay. Designed to add motion
// + texture without competing with cards or UI.

void fragment() {
	vec2 uv = UV;

	// Radial gradient — bluish near the focal point, deep navy at edges.
	float dist = distance(uv, vec2(0.5, 0.35));
	vec3 inner = vec3(0.10, 0.13, 0.20);
	vec3 outer = vec3(0.03, 0.04, 0.08);
	vec3 col = mix(inner, outer, smoothstep(0.0, 0.85, dist));

	// Slow breathing pulse (≈0.4 Hz) — gives the table a sense of life.
	col *= 1.0 + 0.05 * sin(TIME * 0.45);

	// Subtle diamond grid that slowly drifts downward. Low contrast so it
	// reads as texture rather than pattern.
	vec2 grid = abs(fract(uv * vec2(10.0, 18.0) - vec2(0.0, TIME * 0.018)) - 0.5);
	float diamond = smoothstep(0.46, 0.50, grid.x + grid.y);
	col += vec3(0.014, 0.011, 0.006) * diamond;

	COLOR = vec4(col, 1.0);
}
