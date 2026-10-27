extends Control

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const PANEL: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
var roads: Array = []
var objects: Array = []
var map_size := Vector2.ONE
var player_position := Vector2.ZERO
var facing := Vector2.DOWN
var camera_rect := Rect2()
var places: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if roads.is_empty(): return
	draw_style_box(PANEL, Rect2(Vector2.ZERO, size))
	var room := Rect2(8, 8, size.x - 16, size.y - 36)
	var factor: float = minf(room.size.x / map_size.x, room.size.y / map_size.y)
	var image_size: Vector2 = map_size * factor
	var bounds := Rect2(room.position + (room.size - image_size) * 0.5, image_size)
	draw_rect(bounds, Color("536f35"))
	for road: Dictionary in roads:
		var points: Array = road.points
		for index: int in range(points.size() - 1):
			var a := Vector2(float(points[index][0]), float(points[index][1]))
			var b := Vector2(float(points[index + 1][0]), float(points[index + 1][1]))
			draw_line(bounds.position + a * factor, bounds.position + b * factor, Color("d9bd73"), maxf(1.0, float(road.width) * factor))
	for item: Dictionary in objects:
		if str(item.type) != "building": continue
		var at := Vector2(float(item.point[0]), float(item.point[1]))
		draw_rect(Rect2(bounds.position + at * factor - Vector2(4, 5), Vector2(8, 5)), Color("b0ced0"))
	var view := Rect2(bounds.position + camera_rect.position * factor, camera_rect.size * factor)
	draw_rect(view.intersection(bounds), Color("fff3ca88"), false, 1.0)
	for place: Dictionary in places:
		var color := Color("fff0ba") if str(place.id) == "cafe" else Color("f2abc5")
		var point: Vector2 = place.point
		draw_circle(bounds.position + point * factor, 3.0, color)
	var dot: Vector2 = bounds.position + player_position * factor
	draw_circle(dot, 5.0, Color("fff8db"))
	draw_circle(dot, 3.0, Color("c6653b"))
	draw_line(dot, dot + facing * 10.0, Color("fff8db"), 2.0)
	draw_string(FONT, Vector2(12, size.y - 7), "꽃길 마을 · 가게 7곳", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff1cc"))
