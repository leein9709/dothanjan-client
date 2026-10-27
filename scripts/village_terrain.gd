extends Node2D

const ART: Script = preload("res://scripts/village_art.gd")
var map_size := Vector2.ONE
var grass: Texture2D
var soil: Texture2D
var terrain_scale: float = 0.32
var _inner: Array[PackedVector2Array] = []
var _outer: Array[PackedVector2Array] = []

func configure(data: Dictionary) -> bool:
	grass = ART.load_texture("village-ground-grass.png.bytes")
	soil = ART.load_texture("village-ground-path.png.bytes")
	if grass == null or soil == null: return false
	map_size = Vector2(float(data.world_size[0]), float(data.world_size[1]))
	terrain_scale = float(data.terrain_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for road: Dictionary in data.roads:
		var points: Array = road.points
		var radius: float = float(road.width) * 0.5
		var route := PackedVector2Array()
		for point: Array in points: route.append(Vector2(float(point[0]), float(point[1])))
		_inner.append(_ribbon(route, radius))
		_outer.append(_ribbon(route, radius + 4.0))
	queue_redraw()
	return true

func _ribbon(route: PackedVector2Array, radius: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in range(route.size()):
		var tangent: Vector2 = (route[mini(i + 1, route.size() - 1)] - route[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var width: float = radius + sin(i * 1.27) * 1.5 + sin(i * 0.3) * 2.0
		left.append((route[i] + normal * width).snapped(Vector2(2, 2)))
		right.append((route[i] - normal * width).snapped(Vector2(2, 2)))
	var polygon: PackedVector2Array = left.duplicate()
	var end_angle: float = (left[-1] - route[-1]).angle()
	for i: int in range(1, 12):
		polygon.append((route[-1] + Vector2.from_angle(end_angle - PI * i / 12.0) * radius).snapped(Vector2(2, 2)))
	right.reverse()
	polygon.append_array(right)
	var start_angle: float = (right[-1] - route[0]).angle()
	for i: int in range(1, 12):
		polygon.append((route[0] + Vector2.from_angle(start_angle - PI * i / 12.0) * radius).snapped(Vector2(2, 2)))
	return polygon

func _draw() -> void:
	if grass == null or soil == null: return
	# Tile at native density across the world; never stretch a whole-scene bitmap.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * terrain_scale)
	draw_texture_rect(grass, Rect2(Vector2.ZERO, map_size / terrain_scale), true)
	draw_set_transform(Vector2.ZERO)
	for polygon: PackedVector2Array in _outer:
		draw_colored_polygon(polygon, Color("a69447"))
	for polygon: PackedVector2Array in _inner:
		var uvs := PackedVector2Array()
		for point: Vector2 in polygon: uvs.append(point / (soil.get_size() * terrain_scale))
		draw_polygon(polygon, PackedColorArray([Color.WHITE]), uvs, soil)
