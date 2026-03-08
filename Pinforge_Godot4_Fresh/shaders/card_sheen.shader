shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 0.6;
uniform float strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 tint : source_color = vec4(0.6, 0.9, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float diag = uv.x + uv.y;
	float band = smoothstep(0.45, 0.55, sin((diag + t) * 6.2831) * 0.5 + 0.5);
	float alpha = band * strength;
	COLOR = vec4(tint.rgb, alpha);
}
