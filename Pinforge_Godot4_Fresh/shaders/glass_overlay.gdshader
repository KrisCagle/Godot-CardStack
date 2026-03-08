shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.2) = 0.08;
uniform float speed : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 uv = UV;
	float wave = sin((uv.y * 10.0) + TIME * speed) * 0.5 + 0.5;
	float highlight = smoothstep(0.75, 1.0, wave) * strength;

	float n = fract(sin(dot(uv * (TIME * 0.1 + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	float noise = (n - 0.5) * strength * 0.35;

	COLOR = vec4(1.0, 1.0, 1.0, highlight + noise);
}
