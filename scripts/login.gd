extends Control

signal entry_requested

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
const LOGIN_SUBTITLE_FONT_SIZE: int = 29
const SCENE_TEXT_COLOR: Color = Color("fff3d8")
const SCENE_TEXT_SHADOW: Color = Color(0.05, 0.09, 0.04, 0.85)
var login_panel: PanelContainer
var motto: Label
var version: Label
var dialog: TeaModal
var last_login_hint: HBoxContainer
var last_login_badge: PanelContainer
var last_login_icon: TextureRect
var entry_button: Button
var entry_prompt: Label
var logout_button: Button
var _authenticated: bool = false
var _manual_login_pending: bool = false
var _entry_loading: bool = false

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
	motto = _label("아무 일 없는 오후도\n꽤 근사하잖아요.", 54, SCENE_TEXT_COLOR)
	_add_scene_text_shadow(motto)
	add_child(motto)
	version = _label("도트한잔  ·  0.1.0", 24, Color(1, 0.96, 0.84, 0.8))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(32, -37)
	add_child(version)
	_build_entry_gate()
	_build_logout_button()
	dialog = MODAL.new()
	dialog.title = "조금만 기다려 주세요"
	dialog.ok_button_text = "기다릴게요"
	add_child(dialog)
	SocialAuth.sign_in_unavailable.connect(_on_sign_in_unavailable)
	SocialAuth.busy_changed.connect(_on_login_busy)
	SocialAuth.login_finished.connect(_on_login_finished)
	SocialAuth.last_login_provider_changed.connect(_refresh_last_login_hint)
	SocialAuth.logged_out.connect(_on_logged_out)
	SocialAuth.session_changed.connect(_on_session_changed)
	SocialAuth.startup_check_changed.connect(_on_startup_check_changed)
	_on_session_changed(SocialAuth.has_valid_session())
	_on_login_busy(SocialAuth.busy)
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
	var subtitle := _label("구름이 지나가는 동안\n우리도 조금 쉬어요.", LOGIN_SUBTITLE_FONT_SIZE, Color("ced5b6"))
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
	_build_last_login_hint(column)

func _build_last_login_hint(parent: VBoxContainer) -> void:
	last_login_hint = HBoxContainer.new()
	last_login_hint.name = "LastLoginHint"
	last_login_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	last_login_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_login_hint.add_theme_constant_override("separation", 6)
	parent.add_child(last_login_hint)
	last_login_hint.add_child(_label("마지막으로 들어온 문은", 25, Color("ced5b6")))
	last_login_badge = PanelContainer.new()
	last_login_badge.custom_minimum_size = Vector2(26, 26)
	last_login_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	last_login_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_login_hint.add_child(last_login_badge)
	last_login_icon = TextureRect.new()
	last_login_icon.name = "LastLoginIcon"
	last_login_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	last_login_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	last_login_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	last_login_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_login_badge.add_child(last_login_icon)
	last_login_hint.add_child(_label("에요", 25, Color("ced5b6")))
	_refresh_last_login_hint(SocialAuth.get_last_login_provider())

func _refresh_last_login_hint(provider: String) -> void:
	if not is_instance_valid(last_login_hint): return
	last_login_hint.visible = SocialAuth.PROVIDER_NAMES.has(provider)
	if last_login_hint.visible:
		var color: Color = Color("fee500")
		var glyph: Texture2D = KAKAO_ICON
		var glyph_size: int = 16
		if provider == "naver":
			color = Color("03c75a")
			glyph = NAVER_ICON
			glyph_size = 12
		elif provider == "apple":
			color = Color("191919")
			glyph = APPLE_ICON
			glyph_size = 14
		var style := _style(color, 13)
		style.corner_detail = 16
		style.set_content_margin_all(float(26 - glyph_size) * 0.5)
		last_login_badge.add_theme_stylebox_override("panel", style)
		last_login_icon.texture = glyph
		last_login_hint.accessibility_name = "마지막으로 들어온 문은 %s 에요" % SocialAuth.PROVIDER_NAMES[provider]
	else:
		last_login_icon.texture = null
		last_login_hint.accessibility_name = ""
	_layout.call_deferred()

func _build_entry_gate() -> void:
	# One common entry action for touch, mouse and the focused button's ui_accept action.
	entry_button = Button.new()
	entry_button.name = "EntryGate"
	entry_button.accessibility_name = "터치해서 들어가요."
	entry_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		entry_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(entry_button)
	entry_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entry_button.pressed.connect(_on_entry_pressed)
	entry_prompt = _label("터치해서 들어가요.", LOGIN_SUBTITLE_FONT_SIZE, SCENE_TEXT_COLOR)
	entry_prompt.name = "EntryPrompt"
	entry_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_scene_text_shadow(entry_prompt)
	entry_button.add_child(entry_prompt)
	entry_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	entry_button.hide()

func _add_scene_text_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", SCENE_TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

func _build_logout_button() -> void:
	logout_button = Button.new()
	logout_button.name = "Logout"
	logout_button.text = "로그아웃"
	logout_button.accessibility_name = "로그아웃하고 로그인 화면으로 돌아가기"
	logout_button.size = Vector2(108, 50)
	logout_button.add_theme_font_size_override("font_size", 29)
	logout_button.add_theme_color_override("font_color", SCENE_TEXT_COLOR)
	logout_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal: StyleBoxFlat = PANEL_STYLE.duplicate()
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	normal.set_corner_radius_all(14)
	logout_button.add_theme_stylebox_override("normal", normal)
	logout_button.add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Color("e5d29c")
	logout_button.add_theme_stylebox_override("hover", hover)
	logout_button.add_theme_stylebox_override("pressed", normal)
	logout_button.add_theme_stylebox_override("focus", hover)
	logout_button.pressed.connect(_on_logout_pressed)
	logout_button.hide()
	add_child(logout_button)

func _on_logout_pressed() -> void:
	if SocialAuth.busy or _entry_loading or not SocialAuth.has_valid_session(): return
	var completed: bool = await SocialAuth.logout()
	if not is_inside_tree() or completed: return
	dialog.title = "로그아웃을 마치지 못했어요"
	dialog.dialog_text = "로그인 정보를 안전하게 정리하지 못했어요.\n한 번 더 눌러 볼까요?"
	dialog.ok_button_text = "다시 해볼게요"
	dialog.popup_centered()

func _on_session_changed(authenticated: bool) -> void:
	_authenticated = authenticated
	login_panel.visible = not authenticated and not SocialAuth.startup_check_pending and not _entry_loading
	entry_button.visible = authenticated and not SocialAuth.startup_check_pending and not _entry_loading
	logout_button.visible = entry_button.visible
	entry_button.disabled = SocialAuth.busy or _entry_loading
	logout_button.disabled = SocialAuth.busy or _entry_loading
	if authenticated: dialog.hide()
	if entry_button.visible and not SocialAuth.busy and not dialog.visible:
		entry_button.grab_focus()
	_layout.call_deferred()

func _on_startup_check_changed(_checking: bool) -> void:
	_on_session_changed(SocialAuth.has_valid_session())

func _on_entry_pressed() -> void:
	if dialog.visible or SocialAuth.busy or _entry_loading or EntryTransition.busy or SocialAuth.startup_check_pending: return
	if not SocialAuth.has_valid_session():
		_on_session_changed(false)
		return
	_entry_loading = true
	login_panel.hide()
	entry_button.hide()
	logout_button.hide()
	motto.hide()
	version.hide()
	entry_button.release_focus()
	_on_login_busy(SocialAuth.busy)
	entry_requested.emit()
	# The autoload owns the request, covered scene swap and reveal after this node is freed.
	EntryTransition.enter(self)

func _restore_entry_ui() -> void:
	_entry_loading = false
	version.show()
	_on_session_changed(SocialAuth.has_valid_session())
	_on_login_busy(SocialAuth.busy)
	_layout()

func _show_entry_error(code: String) -> void:
	if code in ["session_expired", "session_changed"]: return
	if code == "game_not_ready":
		dialog.show_preparation("사장님의 찻집을 준비하고 있어요.")
		return
	dialog.title = "책을 펼치지 못했어요" if code == "scene_unavailable" else "찻집을 확인하지 못했어요"
	dialog.dialog_text = "잠깐 바람을 고르고 있어요.\n한 번 더 들어가 볼까요?"
	dialog.ok_button_text = "다시 해볼게요"
	dialog.popup_centered()

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
	button.pressed.connect(func() -> void: _request_social_login(provider))
	parent.add_child(button)

func _request_social_login(provider: String) -> void:
	if SocialAuth.busy: return
	_manual_login_pending = provider in ["kakao", "naver"]
	SocialAuth.request_sign_in(provider)

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
	var panel_size := Vector2(390, maxf(460.0, login_panel.get_combined_minimum_size().y))
	login_panel.size = panel_size
	var safe_left: float = 32.0
	var safe_right: float = 32.0
	var safe_bottom: float = 32.0
	var safe_top: float = 22.0
	if OS.get_name() in ["Android", "iOS"]:
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		if window.x > 0 and safe.size.x > 0:
			safe_left = maxf(safe_left, float(safe.position.x) * size.x / float(window.x))
			safe_right = maxf(safe_right, float(window.x - safe.end.x) * size.x / float(window.x))
		if window.y > 0 and safe.size.y > 0:
			safe_top = maxf(safe_top, float(safe.position.y) * size.y / float(window.y))
			safe_bottom = maxf(safe_bottom, float(window.y - safe.end.y) * size.y / float(window.y))
	login_panel.position = Vector2(size.x - panel_size.x - maxf(safe_right, size.x * 0.07), (size.y - panel_size.y) * 0.5)
	motto.position = Vector2(maxf(safe_left, size.x * 0.065), size.y * 0.69)
	motto.visible = size.x > 980 and not _entry_loading
	entry_prompt.offset_left = 32.0
	entry_prompt.offset_right = -32.0
	entry_prompt.offset_top = -safe_bottom - entry_prompt.get_combined_minimum_size().y
	entry_prompt.offset_bottom = -safe_bottom
	logout_button.position = Vector2(size.x - safe_right - logout_button.size.x, safe_top)

func _on_sign_in_unavailable(provider_name: String) -> void:
	dialog.show_preparation("%s 로그인을 준비하고 있어요." % provider_name)

func _on_login_busy(busy: bool) -> void:
	for name: String in ["KakaoLogin", "NaverLogin", "AppleLogin"]:
		var button: Button = find_child(name, true, false)
		if button != null: button.disabled = busy
	entry_button.disabled = busy or _entry_loading
	logout_button.disabled = busy or _entry_loading
	if entry_button.visible and not busy and not _entry_loading and not dialog.visible: entry_button.grab_focus()

func _on_logged_out() -> void:
	# Logging out from this scene also dismisses any previous success/result modal.
	dialog.hide()
	_on_session_changed(false)

func _on_login_finished(success: bool, code: String) -> void:
	var show_failure: bool = _manual_login_pending
	_manual_login_pending = false
	_on_session_changed(SocialAuth.has_valid_session())
	if success:
		dialog.hide()
		if entry_button.visible and not SocialAuth.busy: entry_button.grab_focus()
		return
	# Startup restoration and background refresh fail silently into the sign-in UI.
	if not show_failure: return
	var provider_name: String = str(SocialAuth.PROVIDER_NAMES.get(SocialAuth.current_provider, "소셜"))
	dialog.title = "로그인을 마치지 못했어요"
	var messages: Dictionary = {
		"cancelled": "로그인을 잠깐 멈췄어요.\n마음이 내키면 다시 놀러 와요.",
		"login_expired": "기다리는 시간이 지나갔어요.\n한 번 더 문을 열어 볼까요?",
		"session_expired": "로그인을 한 번 더 확인할게요.\n다시 문을 열어 볼까요?",
		"session_revoked": "로그인을 다시 확인해야 해요.\n한 번 더 문을 열어 볼까요?",
		"session_storage_failed": "로그인 정보를 안전하게 보관하지 못했어요.\n다시 실행해 볼까요?",
		"server_unavailable": "연결이 잠시 쉬고 있어요.\n조금 뒤에 다시 해볼까요?",
		"server_update_required": "찻집 연결을 새로 준비하고 있어요.\n서버를 최신 버전으로 열어 주세요.",
		"provider_not_configured": "%s 로그인 연결이 아직 준비되지 않았어요.\n서버 설정을 확인해 주세요." % provider_name,
		"provider_unavailable": "%s 연결이 잠시 쉬고 있어요.\n조금 뒤에 다시 해볼까요?" % provider_name,
		"login_in_progress": "로그인 창이 아직 열려 있어요.\n창을 닫고 다시 만나 주세요.",
		"too_many_attempts": "조금 쉬었다가 다시 만나 주세요.",
		"sdk_unavailable": "이 기기의 로그인 연결을 준비하지 못했어요.\n다시 실행해 볼까요?",
		"browser_unavailable": "로그인 창을 열지 못했어요.\n다시 해볼까요?"
	}
	dialog.dialog_text = messages.get(code, "%s 로그인을 마치지 못했어요.\n다시 해볼까요?" % provider_name)
	dialog.ok_button_text = "알겠어요" if code == "cancelled" else "다시 해볼게요"
	dialog.popup_centered()

func _capture_preview() -> void:
	if "--preview-login-success" in OS.get_cmdline_user_args():
		# Capture-only appearance preview; no tokens, history or authenticated entry are fabricated.
		_on_session_changed(true)
	elif "--preview-login-failure" in OS.get_cmdline_user_args():
		_manual_login_pending = true
		_on_login_finished(false, "cancelled")
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
