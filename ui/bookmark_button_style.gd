extends StyleBox

var fill_color: Color = Color("426b48")
var border_color: Color = Color.WHITE
var border_width: float = 2.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 4.0 or rect.size.y <= 4.0: return
	var points: PackedVector2Array = _outline(rect)
	if fill_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, points, PackedColorArray([fill_color]))
	var border: PackedVector2Array = points.duplicate()
	border.append(points[0])
	RenderingServer.canvas_item_add_polyline(to_canvas_item, border, PackedColorArray([border_color]), border_width, false)

func _outline(rect: Rect2) -> PackedVector2Array:
	var inset: float = border_width * 0.5
	var left: float = rect.position.x + inset
	var right: float = rect.end.x - inset
	var top: float = rect.position.y + inset
	var bottom: float = rect.end.y - inset
	var radius: float = minf(10.0, (bottom - top) * 0.25)
	var tip_radius: float = minf(2.0, radius)
	var notch: float = minf(22.0, (right - left) * 0.2)
	var points := PackedVector2Array([Vector2(left + radius, top), Vector2(right - tip_radius, top)])
	# Small rounded outer tips surround a genuinely empty, concave V at the right.
	points.append_array(_arc(Vector2(right - tip_radius, top + tip_radius), tip_radius, -PI * 0.5, 0.0, 4))
	points.append(Vector2(right - notch, (top + bottom) * 0.5))
	points.append(Vector2(right, bottom - tip_radius))
	points.append_array(_arc(Vector2(right - tip_radius, bottom - tip_radius), tip_radius, 0.0, PI * 0.5, 4))
	points.append(Vector2(left + radius, bottom))
	points.append_array(_arc(Vector2(left + radius, bottom - radius), radius, PI * 0.5, PI, 6))
	points.append(Vector2(left, top + radius))
	# Omit the repeated first vertex; the polygon closes it and the border adds it.
	points.append_array(_arc(Vector2(left + radius, top + radius), radius, PI, PI * 1.5, 6, false))
	return points

func _arc(center: Vector2, radius: float, from_angle: float, to_angle: float, steps: int, include_end: bool = true) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(1, steps + 1 if include_end else steps):
		var angle: float = lerpf(from_angle, to_angle, float(index) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
