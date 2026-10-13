extends Control

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const SYMBOL: Texture2D = preload("res://assets/branding/app-symbol-transparent.png")
const VILLAGE: Texture2D = preload("res://assets/backgrounds/login-village.png")
const ATMOSPHERE: Script = preload("res://scripts/village_atmosphere.gd")
const VILLAGE_SHADER: Shader = preload("res://shaders/village.gdshader")
const KAKAO_ICON: Texture2D = preload("res://assets/ui/social/kakao.svg")
const NAVER_ICON: Texture2D = preload("res://assets/ui/social/naver.svg")
const APPLE_ICON: Texture2D = preload("res://assets/ui/social/apple.svg")
const PANEL_STYLE: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
const MODAL: Script = preload("res://ui/tea_modal.gd")
var login_panel: PanelContainer
var motto: Label
var dialog: TeaModal

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 34
	theme = ui_theme
	var background := TextureRect.new()
	background.texture = VILLAGE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = VILLAGE_SHADER
	background.material = shader_material
	var atmosphere := Control.new()
	atmosphere.set_script(ATMOSPHERE)
	add_child(atmosphere)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.08, 0.055, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_panel()
	motto = _label("아무 일 없는 오후도\n꽤 근사하잖아요.", 54, Color("fff3d8"))
	motto.add_theme_color_override("font_shadow_color", Color(0.05, 0.09, 0.04, 0.85))
	motto.add_theme_constant_override("shadow_offset_x", 2)
	motto.add_theme_constant_override("shadow_offset_y", 3)
	add_child(motto)
	var version := _label("도트한잔  ·  0.1.0", 24, Color(1, 0.96, 0.84, 0.8))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(32, -37)
	add_child(version)
	dialog = MODAL.new()
	dialog.title = "조금만 기다려 주세요"
	dialog.ok_button_text = "기다릴게요"
	add_child(dialog)
	SocialAuth.sign_in_unavailable.connect(_on_sign_in_unavailable)
	resized.connect(_layout)
	_layout()
	if OS.is_debug_build() and "--capture" in OS.get_cmdline_user_args():
		_capture_preview()

func _build_panel() -> void:
	login_panel = PanelContainer.new()
	login_panel.name = "LoginPanel"
	login_panel.add_theme_stylebox_override("panel", PANEL_STYLE)
	add_child(login_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	login_panel.add_child(column)
	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(0, 76)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_slot)
	var icon := TextureRect.new()
	icon.name = "LoginSymbol"
	icon.texture = SYMBOL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -48
	icon.offset_right = 48
	icon.offset_top = -48
	icon.offset_bottom = 48
	var title := _label("도트한잔", 94, Color("fff0c9"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label("오늘 첫 손님은 누가 찾아올까요?", 29, Color("ced5b6"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	column.add_child(spacer)
	var providers := HBoxContainer.new()
	providers.name = "ProviderIcons"
	providers.alignment = BoxContainer.ALIGNMENT_CENTER
	providers.add_theme_constant_override("separation", 4)
	column.add_child(providers)
	_add_provider_button(providers, "kakao", "카카오로 로그인", Color("fee500"), KAKAO_ICON, 32)
	_add_provider_button(providers, "naver", "네이버로 로그인", Color("03c75a"), NAVER_ICON, 24)
	if SocialAuth.apple_available():
		_add_provider_button(providers, "apple", "Apple로 로그인", Color("191919"), APPLE_ICON, 26)
	var hint_spacer := Control.new()
	hint_spacer.custom_minimum_size.y = 8
	column.add_child(hint_spacer)
	var provider_names: String = "카카오, 네이버, 애플 중" if SocialAuth.apple_available() else "카카오, 네이버 중"
	var hint := _label(provider_names + "\n어떤 문으로 들어올까요?", 25, Color("afbea5"))
	hint.name = "LoginHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Dongle at 25 px leaves a 28 px visual gap; reduce it to about 14 px.
	hint.add_theme_constant_override("line_spacing", hint.get_theme_constant("line_spacing") - 14)
	column.add_child(hint)

func _add_provider_button(parent: HBoxContainer, provider: String, description: String, background: Color, glyph: Texture2D, glyph_size: int) -> void:
	var button := Button.new()
	button.name = "%sLogin" % provider.capitalize()
	button.tooltip_text = description
	button.accessibility_name = description
	button.custom_minimum_size = Vector2(80, 80)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon = glyph
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", glyph_size)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_theme_stylebox_override("normal", _circle_style(background))
	button.add_theme_stylebox_override("hover", _circle_style(background.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _circle_style(background.darkened(0.12)))
	var focus_style := _circle_style(Color.TRANSPARENT)
	focus_style.set_border_width_all(3)
	focus_style.border_color = Color("fff4d1")
	button.add_theme_stylebox_override("focus", focus_style)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: SocialAuth.request_sign_in(provider))
	parent.add_child(button)

func _circle_style(color: Color) -> StyleBoxFlat:
	# Keep a comfortable hit area while drawing a compact 60 px circle.
	var style := _style(color, 30)
	style.set_expand_margin_all(-10)
	style.corner_detail = 16
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _layout() -> void:
	if not is_instance_valid(login_panel):
		return
	var panel_size := Vector2(390, 460)
	login_panel.size = panel_size
	var safe_left: float = 32.0
	var safe_right: float = 32.0
	if OS.get_name() in ["Android", "iOS"]:
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		if window.x > 0 and safe.size.x > 0:
			safe_left = maxf(safe_left, float(safe.position.x) * size.x / float(window.x))
			safe_right = maxf(safe_right, float(window.x - safe.end.x) * size.x / float(window.x))
	login_panel.position = Vector2(size.x - panel_size.x - maxf(safe_right, size.x * 0.07), (size.y - panel_size.y) * 0.5)
	motto.position = Vector2(maxf(safe_left, size.x * 0.065), size.y * 0.69)
	motto.visible = size.x > 980

func _on_sign_in_unavailable(provider_name: String) -> void:
	dialog.show_preparation("%s 로그인을 준비하고 있어요." % provider_name)

func _capture_preview() -> void:
	if "--preview-modal" in OS.get_cmdline_user_args():
		_on_sign_in_unavailable("카카오")
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var file_path: String = OS.get_environment("DOTHANJAN_CAPTURE_PATH")
	if file_path.is_empty():
		file_path = "user://login-preview.png"
	var error: Error = get_viewport().get_texture().get_image().save_png(file_path)
	print("Preview capture: ", file_path, " result=", error)
	get_tree().quit(0 if error == OK else 1)
