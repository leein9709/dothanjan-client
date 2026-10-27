shader_type canvas_item;
render_mode unshaded;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// The dense last layer closes every gap before the scene swap, even on ultrawide screens.
	vec2 pixel = floor(FRAGCOORD.xy / 4.0);
	float pattern = mod(pixel.x + pixel.y * 3.0, 8.0) / 8.0;
	float patch = fract(sin(dot(floor(pixel / 8.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 color = mix(vec3(0.16, 0.30, 0.15), vec3(0.29, 0.43, 0.20), step(pattern, 0.4));
	float alpha = step(patch * 0.98 + 0.01, coverage);
	COLOR = vec4(color, alpha);
}
