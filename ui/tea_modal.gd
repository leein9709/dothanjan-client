class_name TeaModal
extends CanvasLayer

signal confirmed
signal dismissed
signal cancelled

const PANEL_STYLE: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const PREPARATION_CLOSING: String = "짠, 하고 인사드릴게요. 조금만 기다려 주세요!"

var dialog_text: String = "":
	set(value):
		dialog_text = value
		if is_instance_valid(message_label):
			message_label.text = value
var title: String = "도트한잔":
	set(value):
		title = value
		if is_instance_valid(title_label):
			title_label.text = value
var ok_button_text: String = "좋아요":
	set(value):
		ok_button_text = value
		if is_instance_valid(confirm_button):
			confirm_button.text = value
var panel: PanelContainer
var title_label: Label
var message_label: Label
var confirm_button: Button
var cancel_button: Button
var _previous_focus: WeakRef

func _ready() -> void:
	layer = 100
	hide()
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var modal_theme := Theme.new()
	modal_theme.default_font = FONT
	modal_theme.default_font_size = 34
	overlay.theme = modal_theme
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.03, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", PANEL_STYLE)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	title_label = _label(title, 48, Color("fff0c9"))
	column.add_child(title_label)
	message_label = _label(dialog_text, 34, Color("ced5b6"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	column.add_child(actions)
	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = ok_button_text
	confirm_button.custom_minimum_size = Vector2(176, 56)
	confirm_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("e9dcb6")
		if state == "hover":
			button_style.bg_color = Color("fff0c9")
		elif state == "pressed":
			button_style.bg_color = Color("cbbb92")
		button_style.set_corner_radius_all(12)
		confirm_button.add_theme_stylebox_override(state, button_style)
		confirm_button.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", Color("253b2b"))
	confirm_button.add_theme_color_override("font_focus_color", Color("253b2b"))
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("fff4d1")
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(15)
	focus_style.set_expand_margin_all(4)
	confirm_button.add_theme_stylebox_override("focus", focus_style)
	actions.add_child(confirm_button)
	cancel_button = confirm_button.duplicate() as Button
	cancel_button.name = "CancelButton"
	cancel_button.text = "다시 볼게요"
	cancel_button.hide()
	actions.add_child(cancel_button)
	actions.move_child(cancel_button, 0)
	cancel_button.pressed.connect(_cancel)
	# Keep keyboard navigation inside the modal until it closes.
	confirm_button.focus_next = NodePath(".")
	confirm_button.focus_previous = NodePath(".")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		confirm_button.set_focus_neighbor(side, NodePath("."))
	confirm_button.pressed.connect(_confirm)
	visibility_changed.connect(_on_visibility_changed)
	set_process_unhandled_input(false)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func popup_centered() -> void:
	if visible:
		return
	if not cancel_button.visible:
		confirm_button.custom_minimum_size = Vector2(176, 56)
		confirm_button.focus_next = NodePath(".")
		confirm_button.focus_previous = NodePath(".")
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			confirm_button.set_focus_neighbor(side, NodePath("."))
	var focused := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	show()
	confirm_button.grab_focus()

func show_preparation(description: String) -> void:
	title = "조금만 기다려 주세요"
	ok_button_text = "기다릴게요"
	dialog_text = description + "\n" + PREPARATION_CLOSING
	popup_centered()

func _confirm() -> void:
	cancel_button.hide()
	hide()
	confirmed.emit()

func show_confirmation(heading: String, message: String) -> void:
	title = heading
	dialog_text = message
	ok_button_text = "확인"
	confirm_button.custom_minimum_size = Vector2(156, 56)
	cancel_button.custom_minimum_size = Vector2(156, 56)
	cancel_button.show()
	confirm_button.focus_next = confirm_button.get_path_to(cancel_button)
	confirm_button.focus_previous = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_next = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_previous = cancel_button.get_path_to(confirm_button)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		confirm_button.set_focus_neighbor(side, confirm_button.get_path_to(cancel_button))
		cancel_button.set_focus_neighbor(side, cancel_button.get_path_to(confirm_button))
	popup_centered()

func _cancel() -> void:
	cancel_button.hide()
	hide()
	cancelled.emit()

func _on_visibility_changed() -> void:
	set_process_unhandled_input(visible)
	if not visible:
		if _previous_focus != null:
			var previous := _previous_focus.get_ref() as Control
			if is_instance_valid(previous) and previous.is_visible_in_tree():
				previous.grab_focus()
		_previous_focus = null
		dismissed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel()
	# The open modal owns input; gameplay must not react behind it.
	get_viewport().set_input_as_handled()
