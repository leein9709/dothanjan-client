extends Control

var direction := Vector2.ZERO
var enabled: bool = false
var allow_mouse: bool = false
var input_blocked: Callable
var _finger: int = -1
var _mouse_drag: bool = false
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	set_process_input(value)
	if not value: reset()

func reset() -> void:
	direction = Vector2.ZERO
	_knob = Vector2.ZERO
	_finger = -1
	_mouse_drag = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree(): return
	if input_blocked.is_valid() and bool(input_blocked.call()):
		reset()
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and _finger == -1 and _inside(local):
			_finger = event.index
			_update_direction(local)
		elif not event.pressed and event.index == _finger:
			reset()
		else: return
	elif event is InputEventScreenDrag:
		if event.index != _finger: return
		_update_direction(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif allow_mouse and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and _inside(local):
			_mouse_drag = true
			_update_direction(local)
		elif not event.pressed and _mouse_drag: reset()
		else: return
	elif allow_mouse and event is InputEventMouseMotion and _mouse_drag:
		_update_direction(get_global_transform_with_canvas().affine_inverse() * event.position)
	else: return
	get_viewport().set_input_as_handled()

func _inside(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5

func _update_direction(point: Vector2) -> void:
	var travel: float = minf(size.x, size.y) * 0.30
	var raw: Vector2 = (point - size * 0.5) / travel
	if raw.length() < 0.20:
		direction = Vector2.ZERO
		_knob = Vector2.ZERO
	else:
		var angle: float = roundf(raw.angle() / (PI / 4.0)) * PI / 4.0
		direction = Vector2.RIGHT.rotated(angle)
		_knob = direction * travel * minf(raw.length(), 1.0)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.48
	draw_circle(center, radius, Color(0.04, 0.15, 0.11, 0.67))
	draw_arc(center, radius, 0.0, TAU, 64, Color("ede2bdad"), 2.0)
	for i: int in range(8):
		var heading := Vector2.RIGHT.rotated(i * PI / 4.0)
		var side := heading.orthogonal()
		var tip: Vector2 = center + heading * radius * 0.88
		var base: Vector2 = center + heading * radius * 0.63
		var active: bool = direction.dot(heading) > 0.99
		var color := Color("fff0bb") if active else Color("c9d9bf70")
		draw_colored_polygon(PackedVector2Array([tip, base + side * 7, base - side * 7]), color)
	draw_circle(center + _knob, radius * 0.22, Color("d9e4ccdd"))
	draw_circle(center + _knob - Vector2(3, 3), radius * 0.08, Color("fff8dbbb"))
