extends Node2D

const ART: Script = preload("res://scripts/village_art.gd")
const EDGE_SHADER: Shader = preload("res://shaders/owner_motion.gdshader")
static var _material: ShaderMaterial
var _texture: Texture2D
var _polygon := PackedVector2Array()
var _uvs := PackedVector2Array()
var _art_scale := Vector2.ONE

func configure(item: Dictionary, assets: Dictionary) -> void:
	position = Vector2(float(item.point[0]), float(item.point[1]))
	var entry: Dictionary = assets[str(item.asset)]
	_texture = ART.load_texture(str(entry.file))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var origin := Vector2(float(entry.rect[0]), float(entry.rect[1]))
	var anchor := Vector2(float(entry.anchor[0]), float(entry.anchor[1]))
	for point: Array in entry.polygon:
		var source := Vector2(float(point[0]), float(point[1]))
		_polygon.append(source - origin - anchor)
		_uvs.append(source / _texture.get_size())
	_art_scale = Vector2.ONE * float(item.scale)
	if bool(item.get("flip_h", false)): _art_scale.x = -_art_scale.x
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = EDGE_SHADER
	material = _material
	queue_redraw()
	# Local solid footprints exclude roofs and foliage. The visual base is the Y-sort anchor.
	var rect: Array = item.solid
	# Leaves, grass and flowers have no physics body, even when they cover a path.
	if rect.is_empty(): return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(rect[2]), float(rect[3]))
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(float(rect[0]), float(rect[1])) + shape.size * 0.5
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	if _texture == null: return
	# Geometry clips neighbouring atlas sprites; source PNGs remain unmodified.
	draw_set_transform(Vector2.ZERO, 0.0, _art_scale)
	draw_polygon(_polygon, PackedColorArray([Color.WHITE]), _uvs, _texture)
