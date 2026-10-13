extends Control

var elapsed: float = 0.0
var frame_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	frame_time += delta
	if frame_time >= 1.0 / 24.0:
		frame_time = fmod(frame_time, 1.0 / 24.0)
		queue_redraw()

func _draw() -> void:
	# Keep only drifting leaves; extra side flowers and portrait tufts were removed.
	for index: int in range(10):
		var seed_value: float = float(index) * 71.17
		var p := Vector2(fposmod(seed_value * 12.0 + elapsed * 22.0, 1320.0) - 20.0, fposmod(seed_value * 3.0 + elapsed * 9.0, 760.0) - 20.0)
		# Floating leaves stay outside page content and never obscure the controls.
		if p.x > 150.0 and p.x < 1135.0 and p.y > 55.0 and p.y < 650.0: continue
		p = p.snapped(Vector2(2, 2))
		draw_rect(Rect2(p, Vector2(7, 3)), Color("b0be67"))
		draw_rect(Rect2(p + Vector2(2, -2), Vector2(4, 2)), Color("d5ce83"))
