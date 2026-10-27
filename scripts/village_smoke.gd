extends Node2D

var chimneys := PackedVector2Array()
var _time: float = 0.0
var _frame: int = -1
var _puff := PackedVector2Array([
	Vector2(-9, -3), Vector2(-6, -3), Vector2(-6, -8), Vector2(1, -8),
	Vector2(1, -6), Vector2(6, -6), Vector2(6, -2), Vector2(9, -2),
	Vector2(9, 4), Vector2(4, 4), Vector2(4, 7), Vector2(-5, 7),
	Vector2(-5, 4), Vector2(-9, 4)])

func _process(delta: float) -> void:
	_time += delta
	var frame: int = int(_time * 24.0)
	if frame == _frame: return
	_frame = frame
	queue_redraw()

func _draw() -> void:
	var clock: float = float(_frame) / 24.0
	for chimney: int in range(chimneys.size()):
		for puff: int in range(3):
			var age: float = fposmod(clock * 0.18 + float(puff) / 3.0 + chimney * 0.17, 1.0)
			var offset := Vector2(sin(age * PI + chimney) * 12.0 + age * 15.0, -age * 77.0)
			var growth: float = 0.55 + age * 0.70
			var opacity: float = sin(age * PI) * 0.48
			draw_set_transform((chimneys[chimney] + offset).round(), 0.0, Vector2.ONE * growth)
			# Each puff is drawn only at its current position; no previous-frame copy.
			draw_colored_polygon(_puff, Color(0.91, 0.95, 0.88, opacity))
	draw_set_transform(Vector2.ZERO)
