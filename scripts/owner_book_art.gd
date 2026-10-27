extends RefCounted

const PNG_BYTES: String = "res://assets/backgrounds/owner-book.png.bytes"
const UNCOVERED_PNG_BYTES: String = "res://assets/backgrounds/owner-book-clean-plate.png.bytes"
static var _uncovered_background: Texture2D

static func load_background() -> Texture2D:
	# A new source PNG has no .godot import cache when the game is started directly.
	# Ship its unchanged bytes explicitly so source runs and exports use the same art.
	return _load_png(PNG_BYTES)

static func load_uncovered_background() -> Texture2D:
	if _uncovered_background == null:
		_uncovered_background = _load_png(UNCOVERED_PNG_BYTES)
	return _uncovered_background

static func _load_png(path: String) -> Texture2D:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty(): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	return ImageTexture.create_from_image(image)
