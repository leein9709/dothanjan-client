extends Control

const IMAGE_SIZE := Vector2(1672.0, 941.0)
const CHIMNEYS := [Vector2(174, 329), Vector2(855, 244), Vector2(1310, 377)]
const SMOKE_DEPTH := [1.0, 0.68, 1.0]
var elapsed: float = 0.0
var _frame_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	_frame_time += delta
	if _frame_time >= 1.0 / 24.0:
		_frame_time = fmod(_frame_time, 1.0 / 24.0)
		queue_redraw()

func _image_point(uv: Vector2) -> Vector2:
	var factor: float = maxf(size.x / IMAGE_SIZE.x, size.y / IMAGE_SIZE.y)
	return (size - IMAGE_SIZE * factor) * 0.5 + uv * IMAGE_SIZE * factor

func _draw() -> void:
	# Stepped leaf silhouettes remain behind the login controls.
	for index: int in range(34):
		var seed_value: float = float(index) * 73.71
		var x: float = fposmod(seed_value * 13.0 + elapsed * (25.0 + index % 7 * 2.0), size.x + 80.0) - 40.0
		var y: float = fposmod(seed_value * 7.0 + elapsed * (10.0 + index % 4 * 2.0), size.y + 60.0) - 30.0
		x += sin(elapsed * 1.1 + seed_value) * 24.0
		y += sin(elapsed * 1.7 + seed_value) * 8.0
		var tint := Color(0.98, 0.8, 0.36, 0.78) if index % 3 == 0 else Color(0.75, 0.87, 0.44, 0.68)
		var point := Vector2(x, y).snapped(Vector2(2, 2))
		var leaf_width: float = 6.0 + float(index % 3) * 2.0
		var flutter: float = absf(sin(elapsed * 2.6 + seed_value))
		draw_rect(Rect2(point, Vector2(leaf_width, 2 if flutter < 0.35 else 4)), tint)
		if flutter >= 0.35:
			draw_rect(Rect2(point + Vector2(2, -2), Vector2(leaf_width - 4, 2)), tint)
	# Source-image anchors follow the exact same cover/crop as the background.
	var scale_factor: float = maxf(size.x / IMAGE_SIZE.x, size.y / IMAGE_SIZE.y)
	for chimney_index: int in range(CHIMNEYS.size()):
		var origin: Vector2 = _image_point(CHIMNEYS[chimney_index] / IMAGE_SIZE)
		var depth: float = SMOKE_DEPTH[chimney_index]
		for index: int in range(9):
			var phase: float = fposmod(elapsed / (7.0 + chimney_index * 0.4) + float(index) / 9.0 + chimney_index * 0.17, 1.0)
			var alpha: float = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.42, 1.0, phase)) * 0.56
			var width: float = (16.0 + phase * 42.0) * depth * scale_factor
			var drift: float = phase * 32.0 + sin(phase * 7.0 + elapsed * 0.7 + chimney_index) * phase * 15.0
			var offset := Vector2(drift, -phase * 190.0) * depth * scale_factor
			_draw_smoke_puff(origin + offset, width, alpha)

func _draw_smoke_puff(center: Vector2, width: float, alpha: float) -> void:
	# One stepped silhouette avoids the dark overlap of intersecting rectangles.
	var outline := PackedVector2Array([
		Vector2(-0.5, -0.12), Vector2(-0.34, -0.12), Vector2(-0.34, -0.32),
		Vector2(-0.1, -0.32), Vector2(-0.1, -0.44), Vector2(0.2, -0.44),
		Vector2(0.2, -0.28), Vector2(0.4, -0.28), Vector2(0.4, -0.08),
		Vector2(0.5, -0.08), Vector2(0.5, 0.2), Vector2(0.26, 0.2),
		Vector2(0.26, 0.32), Vector2(-0.28, 0.32), Vector2(-0.28, 0.18),
		Vector2(-0.5, 0.18)
	])
	for index: int in range(outline.size()):
		outline[index] = (center + outline[index] * width).snapped(Vector2(2, 2))
	draw_colored_polygon(outline, Color(0.99, 0.95, 0.84, alpha))
