extends RefCounted

const PNG_BYTES: String = "res://assets/backgrounds/owner-book.png.bytes"

static func load_background() -> Texture2D:
	# A new source PNG has no .godot import cache when the game is started directly.
	# Ship its unchanged bytes explicitly so source runs and exports use the same art.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PNG_BYTES)
	if bytes.is_empty(): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	return ImageTexture.create_from_image(image)
