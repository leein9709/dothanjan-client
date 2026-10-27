extends Control

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const CAFE_ART: Script = preload("res://scripts/starter_cafe_art.gd")
const OWNER_CATALOG: Script = preload("res://scripts/owner_setup.gd")
const PROFILE_PANEL: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
const PROFILE_SIZE := Vector2(276, 98)
const PROFILE_PORTRAITS: Dictionary = {
	"human-male": Rect2(290, 85, 660, 660),
	"human-female": Rect2(310, 80, 660, 660),
	"cat-ginger": Rect2(195, 125, 710, 710),
	"cat-black": Rect2(195, 125, 710, 710),
	"cat-white-gray": Rect2(195, 125, 710, 710),
	"fox-orange": Rect2(265, 245, 625, 625),
	"fox-white": Rect2(265, 245, 625, 625),
	"rabbit-white": Rect2(275, 60, 730, 730),
	"rabbit-light-brown": Rect2(275, 60, 730, 730),
}
const SIDE_MENU: Script = preload("res://ui/tea_side_menu.gd")
const MODAL: Script = preload("res://ui/tea_modal.gd")
const VILLAGE: Script = preload("res://scripts/village_walk.gd")
var room_ready: bool = false
var cafe_profile: Dictionary = {}
var background: Texture2D
var owner_clip: Control
var owner_image: TextureRect
var name_label: Label
var profile_card: PanelContainer
var profile_avatar: TextureRect
var game_title_label: Label
var menu_button: Button
var side_menu: CanvasLayer
var dialog: TeaModal
var _logout_waiting: bool = false
var room: TextureRect
var door_button: Button
var door_hint: Button
var village: VILLAGE
var _owner_texture: Texture2D
var _outside: bool = false
var _changing_place: bool = false
var _curtain: ColorRect

class MenuLines extends Control:
	func _draw() -> void:
		for row: int in range(3):
			draw_rect(Rect2(0, row * 10, 30, 4), Color("fff1cc"))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not SocialAuth.has_valid_session():
		get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
		return
	cafe_profile = BookTransition.take_profile()
	background = CAFE_ART.load_background()
	if background == null or cafe_profile.is_empty():
		get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
		return
	var owner_texture: Texture2D
	for owner: Dictionary in OWNER_CATALOG.OWNERS:
		if str(owner.id) == str(cafe_profile.get("owner_character_id", "")):
			owner_texture = owner.texture
			break
	if owner_texture == null:
		get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
		return
	_owner_texture = owner_texture
	room = TextureRect.new()
	room.name = "CafeBackground"
	room.texture = background
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The approved full sprite stands behind the existing counter; crop only its
	# occluded lower half, without redrawing or changing the original proportions.
	owner_clip = Control.new()
	owner_clip.clip_contents = true
	owner_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(owner_clip)
	owner_image = TextureRect.new()
	owner_image.texture = owner_texture
	owner_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	owner_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_clip.add_child(owner_image)
	_build_door()
	_build_profile(owner_texture)
	_build_menu()
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 90
	add_child(fade_layer)
	_curtain = ColorRect.new()
	_curtain.color = Color("203629")
	_curtain.modulate.a = 0.0
	_curtain.hide()
	fade_layer.add_child(_curtain)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	SocialAuth.session_changed.connect(_on_session_changed)
	SocialAuth.busy_changed.connect(_on_auth_busy_changed)
	SocialAuth.login_finished.connect(_on_logout_finished)
	_on_auth_busy_changed(SocialAuth.busy)
	_layout()
	room_ready = true

func _build_menu() -> void:
	menu_button = Button.new()
	menu_button.name = "OpenMenu"
	menu_button.size = Vector2(64, 60)
	menu_button.accessibility_name = "메뉴 열기"
	menu_button.tooltip_text = "메뉴"
	menu_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = PROFILE_PANEL.duplicate()
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.set_corner_radius_all(16)
		if state in ["hover", "focus"]: style.border_color = Color("e5d29c")
		menu_button.add_theme_stylebox_override(state, style)
	menu_button.pressed.connect(_on_menu_pressed)
	add_child(menu_button)
	var lines := MenuLines.new()
	lines.position = Vector2(17, 18)
	lines.size = Vector2(30, 24)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(lines)
	side_menu = SIDE_MENU.new()
	add_child(side_menu)
	side_menu.connect("logout_requested", _on_game_logout)
	dialog = MODAL.new()
	add_child(dialog)

func _on_menu_pressed() -> void:
	if BookTransition.busy or EntryTransition.busy or _changing_place or _logout_waiting or dialog.visible: return
	side_menu.call("toggle")

func _on_auth_busy_changed(value: bool) -> void:
	side_menu.call("set_auth_busy", value)

func _on_game_logout() -> void:
	if SocialAuth.busy or _logout_waiting or not SocialAuth.has_valid_session(): return
	_logout_waiting = true
	side_menu.call("set_logout_busy", true)
	# The persistent auth service finishes revocation after this scene is freed.
	# Local storage failure is reported synchronously through login_finished.
	SocialAuth.logout()

func _on_logout_finished(success: bool, _code: String) -> void:
	if not _logout_waiting or success: return
	_logout_waiting = false
	side_menu.call("set_logout_busy", false)
	dialog.title = "로그아웃을 마치지 못했어요"
	dialog.dialog_text = "로그인 정보를 안전하게 정리하지 못했어요.\n한 번 더 눌러 볼까요?"
	dialog.ok_button_text = "다시 해볼게요"
	dialog.popup_centered()

func _build_profile(owner_texture: Texture2D) -> void:
	profile_card = PanelContainer.new()
	profile_card.name = "CafeProfile"
	profile_card.custom_minimum_size = PROFILE_SIZE
	profile_card.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_card.tooltip_text = str(cafe_profile.cafe_name)
	var panel: StyleBoxFlat = PROFILE_PANEL.duplicate()
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	panel.set_corner_radius_all(16)
	profile_card.add_theme_stylebox_override("panel", panel)
	add_child(profile_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_card.add_child(row)
	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(78, 78)
	avatar_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	avatar_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color("f6e7c5")
	avatar_style.border_color = Color("bfa773")
	avatar_style.set_border_width_all(1)
	avatar_style.set_corner_radius_all(12)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		avatar_style.set_content_margin(side, 4)
	avatar_frame.add_theme_stylebox_override("panel", avatar_style)
	row.add_child(avatar_frame)
	profile_avatar = TextureRect.new()
	profile_avatar.name = "ProfileOwner"
	var portrait := AtlasTexture.new()
	portrait.atlas = owner_texture
	portrait.region = PROFILE_PORTRAITS[str(cafe_profile.owner_character_id)]
	portrait.filter_clip = true
	profile_avatar.texture = portrait
	profile_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	profile_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	profile_avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	profile_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(profile_avatar)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	game_title_label = _profile_text("도트한잔", 24, Color("fff1cc99"))
	game_title_label.name = "GameTitle"
	names.add_child(game_title_label)
	name_label = _profile_text(str(cafe_profile.cafe_name), 27, Color("fff1cc"))
	name_label.name = "CafeName"
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(name_label)
	# Display-only profile: clicking opens no menu and changes no account data.

func _profile_text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	if background == null or owner_image == null: return
	var scale_factor: float = maxf(size.x / background.get_width(), size.y / background.get_height())
	var room_size: Vector2 = background.get_size() * scale_factor
	var room_origin: Vector2 = (size - room_size) * 0.5
	owner_clip.position = room_origin + room_size * Vector2(0.70, 0.34)
	owner_clip.size = room_size * Vector2(0.14, 0.222)
	owner_image.size = Vector2(owner_clip.size.x, room_size.y * 0.38)
	door_button.position = room_origin + room_size * Vector2(0.895, 0.28)
	door_button.size = room_size * Vector2(0.09, 0.62)
	var safe := Rect2(Vector2.ZERO, size)
	var pixels: Vector2i = DisplayServer.window_get_size()
	if OS.get_name() in ["Android", "iOS"] and pixels.x > 0 and pixels.y > 0:
		var area: Rect2i = DisplayServer.get_display_safe_area()
		var ratio: Vector2 = size / Vector2(pixels)
		if area.size.x > 0 and area.size.y > 0:
			safe = Rect2(Vector2(area.position) * ratio, Vector2(area.size) * ratio).intersection(safe)
	var profile_scale: float = minf(1.0, minf(safe.size.x / 1280.0, safe.size.y / 720.0))
	profile_card.scale = Vector2.ONE * profile_scale
	profile_card.size = PROFILE_SIZE
	profile_card.position = safe.position + Vector2(24, 14) * profile_scale
	menu_button.scale = Vector2.ONE * profile_scale
	menu_button.position = Vector2(safe.end.x - (menu_button.size.x + 24) * profile_scale, safe.position.y + 14 * profile_scale)
	side_menu.call("layout_for", safe, profile_scale)
	door_hint.scale = Vector2.ONE * profile_scale
	door_hint.size = Vector2(134, 52)
	door_hint.position = (room_origin + room_size * Vector2(0.94, 0.86) - door_hint.size * profile_scale * 0.5).clamp(safe.position, safe.end - door_hint.size * profile_scale)
	if village != null: village.layout_for(safe, profile_scale)

func _build_door() -> void:
	door_button = Button.new()
	door_button.name = "CafeDoor"
	door_button.accessibility_name = "마을로 나가기"
	door_button.tooltip_text = "꽃길 골목으로 나가요"
	door_button.focus_mode = Control.FOCUS_NONE
	door_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus"]:
		door_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	door_button.pressed.connect(_leave_cafe)
	add_child(door_button)
	door_hint = Button.new()
	door_hint.name = "VillageDoorHint"
	door_hint.text = "마을로 ›"
	door_hint.focus_mode = Control.FOCUS_NONE
	door_hint.add_theme_font_override("font", FONT)
	door_hint.add_theme_font_size_override("font_size", 30)
	door_hint.add_theme_color_override("font_color", Color("fff1cc"))
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = PROFILE_PANEL.duplicate()
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		door_hint.add_theme_stylebox_override(state, style)
	door_hint.pressed.connect(_leave_cafe)
	add_child(door_hint)

func _world_input_blocked() -> bool:
	var menu_overlay: Control = side_menu.get("overlay")
	return _changing_place or BookTransition.busy or EntryTransition.busy or _logout_waiting or SocialAuth.busy or not SocialAuth.has_valid_session() or dialog.visible or menu_overlay.visible

func _leave_cafe() -> void:
	if _world_input_blocked(): return
	if village == null:
		village = VILLAGE.new()
		village.name = "FlowerLane"
		add_child(village)
		move_child(village, room.get_index() + 1)
		if not village.configure(_owner_texture, str(cafe_profile.owner_character_id), OWNER_CATALOG.OWNERS, _world_input_blocked):
			village.queue_free()
			village = null
			_village_message("마을을 펼치지 못했어요", "산책길 그림을 불러오지 못했어요.\n잠시 뒤 문을 다시 열어볼까요?", "다시 해볼게요")
			return
		village.enter_cafe_requested.connect(_return_to_cafe)
		village.message_requested.connect(_village_message)
		village.preparation_requested.connect(dialog.show_preparation)
		_layout()
	_change_place(true)

func _return_to_cafe() -> void:
	if not _world_input_blocked(): _change_place(false)

func _change_place(outside: bool) -> void:
	if _changing_place or outside == _outside: return
	_changing_place = true
	_curtain.show()
	var cover := create_tween()
	cover.tween_property(_curtain, "modulate:a", 1.0, 0.20)
	await cover.finished
	if not SocialAuth.has_valid_session(): return
	_outside = outside
	room.visible = not outside
	owner_clip.visible = not outside
	door_button.visible = not outside
	door_hint.visible = not outside
	village.set_active(outside)
	_layout()
	var reveal := create_tween()
	reveal.tween_property(_curtain, "modulate:a", 0.0, 0.24)
	await reveal.finished
	_curtain.hide()
	_changing_place = false

func _village_message(heading: String, message: String, answer: String) -> void:
	dialog.title = heading
	dialog.dialog_text = message
	dialog.ok_button_text = answer
	dialog.popup_centered()

func _on_session_changed(authenticated: bool) -> void:
	if not authenticated: get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
