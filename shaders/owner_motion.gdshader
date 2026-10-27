shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Near-transparent generation fringe is not part of the character outline.
	if (pixel.a < 0.125) { discard; }
	COLOR = pixel;
}
