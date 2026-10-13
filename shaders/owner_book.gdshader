shader_type canvas_item;
render_mode unshaded;

// Move whole botanical edges and their immediate surroundings together.
// Color masks leave stationary outlines; these envelopes avoid that split.
float plant_region(vec2 uv, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.45, 1.0, length((uv - center) / radius));
}

void fragment() {
	float plants = 0.0;
	// Decorations inside the pages, away from the binding and page edges.
	plants = max(plants, plant_region(UV, vec2(0.196, 0.183), vec2(0.061, 0.089)));
	plants = max(plants, plant_region(UV, vec2(0.162, 0.282), vec2(0.026, 0.097)));
	plants = max(plants, plant_region(UV, vec2(0.166, 0.547), vec2(0.030, 0.170)));
	plants = max(plants, plant_region(UV, vec2(0.217, 0.773), vec2(0.080, 0.073)));
	plants = max(plants, plant_region(UV, vec2(0.453, 0.177), vec2(0.028, 0.070)));
	plants = max(plants, plant_region(UV, vec2(0.454, 0.799), vec2(0.029, 0.041)));
	plants = max(plants, plant_region(UV, vec2(0.537, 0.177), vec2(0.028, 0.073)));
	plants = max(plants, plant_region(UV, vec2(0.537, 0.799), vec2(0.028, 0.043)));
	plants = max(plants, plant_region(UV, vec2(0.797, 0.170), vec2(0.062, 0.067)));
	plants = max(plants, plant_region(UV, vec2(0.840, 0.280), vec2(0.024, 0.102)));
	plants = max(plants, plant_region(UV, vec2(0.839, 0.549), vec2(0.024, 0.165)));
	plants = max(plants, plant_region(UV, vec2(0.792, 0.780), vec2(0.068, 0.063)));
	// Existing ivy and flowers outside the book.
	plants = max(plants, plant_region(UV, vec2(0.031, 0.035), vec2(0.100, 0.071)));
	plants = max(plants, plant_region(UV, vec2(0.021, 0.309), vec2(0.035, 0.230)));
	plants = max(plants, plant_region(UV, vec2(0.032, 0.545), vec2(0.057, 0.119)));
	plants = max(plants, plant_region(UV, vec2(0.328, 0.015), vec2(0.049, 0.049)));
	plants = max(plants, plant_region(UV, vec2(0.551, 0.023), vec2(0.072, 0.053)));
	plants = max(plants, plant_region(UV, vec2(0.855, 0.022), vec2(0.079, 0.055)));
	plants = max(plants, plant_region(UV, vec2(0.939, 0.236), vec2(0.038, 0.225)));
	plants = max(plants, plant_region(UV, vec2(0.924, 0.530), vec2(0.021, 0.157)));
	plants = max(plants, plant_region(UV, vec2(0.978, 0.899), vec2(0.125, 0.149)));
	plants = max(plants, plant_region(UV, vec2(0.132, 0.930), vec2(0.041, 0.051)));
	float time = floor(TIME * 24.0) / 24.0;
	vec2 sway = vec2(sin(time * 1.25 + UV.y * 8.0) * 3.0,
		sin(time * 1.1 + UV.x * 9.0));
	vec2 pixel_shift = round(sway * plants);
	vec2 sample_uv = clamp(UV + pixel_shift * TEXTURE_PIXEL_SIZE,
		TEXTURE_PIXEL_SIZE * 0.5, vec2(1.0) - TEXTURE_PIXEL_SIZE * 0.5);
	// One nearest-filtered sample, with no original/moved crossfade or trails.
	COLOR = texture(TEXTURE, sample_uv);
}
