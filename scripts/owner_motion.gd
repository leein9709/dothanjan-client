extends RefCounted

const CATALOG_PATH: String = "res://assets/characters/motion/catalog.json.bytes"
const DIRECTIONS: Array[String] = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
static var _catalog: Dictionary = {}
static var _packs: Dictionary = {}

static func direction_for(vector: Vector2) -> String:
	var sector: int = posmod(int(round(vector.angle() / (PI / 4.0))), 8)
	return ["e", "se", "s", "sw", "w", "nw", "n", "ne"][sector]

static func load_pack(id: String) -> Dictionary:
	if _packs.has(id): return _packs[id]
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if not parsed is Dictionary: return {}
		_catalog = parsed
	var characters: Dictionary = _catalog.get("characters", {})
	if not characters.has(id): return {}
	var entry: Dictionary = characters[id]
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(str(entry.sheet))) != OK: return {}
	var sheet: Texture2D = ImageTexture.create_from_image(image)
	var animations: Dictionary = {}
	for direction: String in DIRECTIONS:
		var rows: Dictionary = entry.animations.get(direction, {})
		for state: String in ["idle", "walk"]:
			var frames: Array[Dictionary] = []
			for item: Dictionary in rows.get(state, []):
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(float(item.rect[0]), float(item.rect[1]), float(item.rect[2]), float(item.rect[3]))
				atlas.filter_clip = true
				frames.append({"texture": atlas, "anchor": Vector2(float(item.anchor[0]), float(item.anchor[1]))})
			if frames.size() != (2 if state == "idle" else 4): return {}
			animations[state + "_" + direction] = frames
	var pack: Dictionary = {"scale": float(entry.scale), "animations": animations}
	_packs[id] = pack
	return pack
