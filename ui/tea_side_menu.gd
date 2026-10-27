extends CanvasLayer

signal logout_requested

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const PANEL_STYLE: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
const SLIDE_SECONDS: float = 0.26

var overlay: Control
var shade: ColorRect
var drawer: PanelContainer
var drawer_style: StyleBoxFlat
var title_label: Label
var close_button: Button
var logout_button: Button
var is_open: bool = false
var openness: float = 0.0
var drawer_width: float = 360.0
var motion: Tween
var _previous_focus: WeakRef
var _logout_waiting: bool = false
var _auth_busy: bool = false

func _ready() -> void:
	layer = 70
	overlay = Control.new()
	overlay.name = "MenuOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu_theme := Theme.new()
	menu_theme.default_font = FONT
	menu_theme.default_font_size = 34
	overlay.theme = menu_theme
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.025, 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_on_outside_input)
	drawer = PanelContainer.new()
	drawer.name = "RightMenu"
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer_style = PANEL_STYLE.duplicate()
	drawer_style.bg_color = Color(0.055, 0.12, 0.09, 0.98)
	drawer.add_theme_stylebox_override("panel", drawer_style)
	overlay.add_child(drawer)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	drawer.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	column.add_child(heading)
	title_label = Label.new()
	title_label.text = "메뉴"
	title_label.add_theme_color_override("font_color", Color("fff1cc"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title_label)
	close_button = _button("닫기")
	close_button.accessibility_name = "메뉴 닫기"
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(space)
	logout_button = _button("로그아웃")
	logout_button.name = "MenuLogout"
	logout_button.accessibility_name = "로그아웃하고 로그인 화면으로 돌아가기"
	logout_button.pressed.connect(_request_logout)
	column.add_child(logout_button)
	# Keyboard focus remains inside the open drawer.
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		close_button.set_focus_neighbor(side, close_button.get_path_to(logout_button))
		logout_button.set_focus_neighbor(side, logout_button.get_path_to(close_button))
	close_button.focus_next = close_button.get_path_to(logout_button)
	close_button.focus_previous = close_button.get_path_to(logout_button)
	logout_button.focus_next = logout_button.get_path_to(close_button)
	logout_button.focus_previous = logout_button.get_path_to(close_button)
	overlay.hide()
	set_process_unhandled_input(false)

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color("fff1cc"))
	button.add_theme_color_override("font_disabled_color", Color("fff1cc99"))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = PANEL_STYLE.duplicate()
		style.set_corner_radius_all(12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		if state in ["hover", "focus"]: style.border_color = Color("e5d29c")
		button.add_theme_stylebox_override(state, style)
	return button

func layout_for(safe: Rect2, ui_scale: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var right_inset: float = maxf(0.0, viewport_size.x - safe.end.x)
	drawer_width = minf(360.0 * ui_scale + right_inset, viewport_size.x * 0.82)
	drawer_style.content_margin_left = 24 * ui_scale
	drawer_style.content_margin_right = 24 * ui_scale + right_inset
	drawer_style.content_margin_top = safe.position.y + 18 * ui_scale
	drawer_style.content_margin_bottom = maxf(0.0, viewport_size.y - safe.end.y) + 24 * ui_scale
	drawer.size = Vector2(drawer_width, viewport_size.y)
	title_label.add_theme_font_size_override("font_size", maxi(18, int(42 * ui_scale)))
	close_button.add_theme_font_size_override("font_size", maxi(16, int(28 * ui_scale)))
	logout_button.add_theme_font_size_override("font_size", maxi(18, int(35 * ui_scale)))
	close_button.custom_minimum_size = Vector2(84, 50) * ui_scale
	logout_button.custom_minimum_size = Vector2(0, 62) * ui_scale
	_set_openness(openness)

func toggle() -> void:
	if is_open: close()
	else: _animate(true)

func close() -> void:
	if _logout_waiting or not is_open: return
	_animate(false)

func _animate(opening: bool) -> void:
	if motion != null and motion.is_valid(): motion.kill()
	if opening and not overlay.visible:
		var focused: Control = get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focused) if focused != null else null
		close_button.grab_focus.call_deferred()
	is_open = opening
	overlay.show()
	set_process_unhandled_input(true)
	motion = create_tween()
	motion.tween_method(_set_openness, openness, 1.0 if opening else 0.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not opening: motion.tween_callback(_finish_close)

func _set_openness(value: float) -> void:
	openness = value
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	drawer.position = Vector2(viewport_size.x - drawer_width * openness, 0.0).round()
	shade.color = Color(0.02, 0.04, 0.025, 0.32 * openness)

func _finish_close() -> void:
	overlay.hide()
	set_process_unhandled_input(false)
	if _previous_focus != null:
		var previous := _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	_previous_focus = null

func _on_outside_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		close()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func set_auth_busy(value: bool) -> void:
	_auth_busy = value
	_refresh_actions()

func set_logout_busy(value: bool) -> void:
	_logout_waiting = value
	_refresh_actions()

func _refresh_actions() -> void:
	logout_button.disabled = _auth_busy or _logout_waiting
	close_button.disabled = _logout_waiting
	logout_button.text = "나가는 중…" if _logout_waiting else "로그아웃"
	var close_target: NodePath = NodePath(".") if logout_button.disabled else close_button.get_path_to(logout_button)
	close_button.focus_next = close_target
	close_button.focus_previous = close_target
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		close_button.set_focus_neighbor(side, close_target)

func _request_logout() -> void:
	if logout_button.disabled: return
	logout_requested.emit()
