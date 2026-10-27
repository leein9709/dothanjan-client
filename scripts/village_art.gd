extends RefCounted

const BASE: String = "res://assets/backgrounds/"
const LAYOUT_BYTES: String = BASE + "village-topdown-layout.json.bytes"
static var _textures: Dictionary = {}
static var _sprites: Dictionary = {}
static var _layout: Dictionary = {}

static func load_texture(file: String) -> Texture2D:
	if _textures.has(file): return _textures[file]
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(BASE + file)
	if bytes.is_empty(): return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK: return null
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_textures[file] = texture
	return texture

static func load_layout() -> Dictionary:
	if not _layout.is_empty(): return _layout
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(LAYOUT_BYTES)
	if bytes.is_empty(): return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary: return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != 4: return {}
	if not data.get("assets") is Dictionary or not data.get("objects") is Array: return {}
	if data.get("places", []).size() != 7 or data.get("roads", []).is_empty(): return {}
	_layout = data
	return _layout

static func load_sprite(id: String) -> AtlasTexture:
	if _sprites.has(id): return _sprites[id]
	var data: Dictionary = load_layout()
	if not data.get("assets", {}).has(id): return null
	var entry: Dictionary = data.assets[id]
	var source: Texture2D = load_texture(str(entry.file))
	if source == null: return null
	var rect: Array = entry.rect
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	texture.filter_clip = true
	_sprites[id] = texture
	return texture
