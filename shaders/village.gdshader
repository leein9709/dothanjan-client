shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float foliage = step(original.r * 1.12, original.g) * step(original.b * 1.08, original.g);
	float breeze_time = floor(TIME * 12.0) / 12.0;
	float wave = sin(breeze_time * 1.15 + floor(UV.y * 60.0) * 0.72 + UV.x * 8.0);
	float gust = 0.8 + 0.2 * sin(breeze_time * 0.43);
	vec2 sway = vec2(round(wave * 3.0 * gust), round(sin(breeze_time + UV.x * 18.0) * gust));
	sway *= TEXTURE_PIXEL_SIZE * foliage;
	vec4 shifted = texture(TEXTURE, clamp(UV + sway, vec2(0.0), vec2(1.0)));
	COLOR = vec4(shifted.rgb, 1.0);
}
