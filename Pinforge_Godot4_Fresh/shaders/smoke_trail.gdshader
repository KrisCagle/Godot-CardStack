shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.88, 0.92, 1.0, 0.75);
uniform float cutoff : hint_range(0.0, 0.4) = 0.08;
uniform float softness : hint_range(0.01, 0.8) = 0.24;
uniform float scroll = 0.0;
uniform float tiling_x : hint_range(1.0, 16.0) = 7.0;
uniform float tiling_y : hint_range(1.0, 8.0) = 2.0;

void fragment() {
	vec2 uv = vec2(fract(UV.x * tiling_x + scroll), fract(UV.y * tiling_y));
	vec4 tex = texture(TEXTURE, uv);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float smoke_mask = smoothstep(0.0, cutoff + softness, lum);
	// Keep a faint base alpha so compressed textures don't fully disappear.
	float alpha = (smoke_mask * 0.9 + 0.08) * COLOR.a * tint.a;
	vec3 color = tint.rgb * (0.75 + smoke_mask * 0.35);
	COLOR = vec4(color, alpha);
}
