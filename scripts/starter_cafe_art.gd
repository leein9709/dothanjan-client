extends RefCounted

const PNG_BYTES: String = "res://assets/backgrounds/cafe-01-interior-day-clear.png.bytes"
static var cached_background: Texture2D

static func load_background() -> Texture2D:
	if cached_background != null: return cached_background
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PNG_BYTES)
	if bytes.is_empty(): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	cached_background = ImageTexture.create_from_image(image)
	return cached_background
