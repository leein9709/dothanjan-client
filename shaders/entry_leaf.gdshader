shader_type canvas_item;
render_mode unshaded;

uniform float tint = 0.0;

void fragment() {
	// A coarse pixel silhouette, stepped vein and ordered stippling; never blur.
	vec2 pixel = floor(UV * vec2(40.0, 28.0));
	vec2 p = (pixel + 0.5) / vec2(40.0, 28.0);
	float x = (p.x - 0.08) / 0.84;
	float width = sin(clamp(x, 0.0, 1.0) * 3.14159265) * 0.39;
	width -= mod(pixel.x, 3.0) == 0.0 ? 0.025 : 0.0;
	float center = 0.5 + sin(x * 3.14159265) * 0.05;
	float inside = step(0.0, x) * step(x, 1.0) * step(abs(p.y - center), width);
	float shade = clamp(0.52 + (center - p.y) * 0.8 + tint * 0.12, 0.0, 1.0);
	float dots = mod(pixel.x + pixel.y * 2.0, 4.0) / 4.0;
	vec3 dark = vec3(0.12, 0.25, 0.13);
	vec3 green = vec3(0.28, 0.43, 0.19);
	vec3 light = vec3(0.52, 0.62, 0.28);
	vec3 color = mix(dark, green, step(dots, shade));
	color = mix(color, light, step(dots, shade - 0.33));
	float vein = step(abs(p.y - center), 0.022) * step(0.14, x) * step(x, 0.86);
	color = mix(color, light, vein);
	COLOR = vec4(color, inside);
}
