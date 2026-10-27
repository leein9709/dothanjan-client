extends Control

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const BOOK_ART: Script = preload("res://scripts/owner_book_art.gd")
const BOOK_SHADER: Shader = preload("res://shaders/owner_book.gdshader")
const FLORA: Script = preload("res://scripts/owner_book_flora.gd")
const MODAL: Script = preload("res://ui/tea_modal.gd")
const BOOKMARK_STYLE: Script = preload("res://ui/bookmark_button_style.gd")
const DESIGN_SIZE := Vector2(1280, 720)
# Keep the established page coordinates and uniform UI scale.
const LAYOUT_SIZE := Vector2(1280, 752)
const LINE_CHARACTER_SECONDS: float = 0.045
const OWNERS: Array[Dictionary] = [
	{"id": "human-male", "name": "도윤", "texture": preload("res://assets/characters/owners/human-male-idle.png")},
	{"id": "human-female", "name": "하린", "texture": preload("res://assets/characters/owners/human-female-idle.png")},
	{"id": "cat-ginger", "name": "버터", "texture": preload("res://assets/characters/owners/cat-ginger-idle.png")},
	{"id": "cat-black", "name": "까망", "texture": preload("res://assets/characters/owners/cat-black-idle.png")},
	{"id": "cat-white-gray", "name": "반달", "texture": preload("res://assets/characters/owners/cat-white-gray-idle.png")},
	{"id": "fox-orange", "name": "홍시", "texture": preload("res://assets/characters/owners/fox-orange-idle.png")},
	{"id": "fox-white", "name": "설이", "texture": preload("res://assets/characters/owners/fox-white-idle.png")},
	{"id": "rabbit-white", "name": "캐럿", "texture": preload("res://assets/characters/owners/rabbit-white-idle.png")},
	{"id": "rabbit-light-brown", "name": "라떼", "texture": preload("res://assets/characters/owners/rabbit-light-brown-idle.png")},
]
const OWNER_LINES: Dictionary = {
	"human-male": "앞치마가\n저를 채용했어요.",
	"human-female": "오늘도 열심히…\n쉬어 볼까요?",
	"cat-ginger": "앞치마 입으니\n제법 사장님이죠?",
	"cat-black": "차는 제가 탈게요.\n간은 보장 못 해요.",
	"cat-white-gray": "저 제법\n찻집에 잘 어울리죠?",
	"fox-orange": "사장님이 됐어요.\n어쩌다 보니요.",
	"fox-white": "일할 준비 됐어요!\n마음의 준비만요.",
	"rabbit-white": "찻집은 처음인데\n예쁜건 경력이에요.",
	"rabbit-light-brown": "찻집은 처음인데\n귀여운 건 경력이에요.",
}
var selected_owner_id: String = "human-male"
var design: Control
var portrait: TextureRect
var owner_caption: Label
var owner_line: Label
var name_input: LineEdit
var name_check_button: Button
var name_check_hint: RichTextLabel
var checked_cafe_name: String = ""
var checked_name_input: String = ""
var name_preview: String = ""
var name_revision: int = 0
var name_check_busy: bool = false
var start_button: Button
var back_button: Button
var cards: Array[Button] = []
var marks: Array[Control] = []
var keyboard_height: int = 0
var background: Texture2D
var line_elapsed: float = 0.0
var line_typing: bool = false
var line_characters: int = 0
var entering_cafe: bool = false
var setup_ui: Array[Control] = []
var dialog: TeaModal
var pending_profile: Dictionary = {}
var saved_profile: Dictionary = {}

class CheckMark extends Control:
	func _draw() -> void:
		draw_circle(Vector2(15, 15), 14, Color("dfa933"))
		draw_arc(Vector2(15, 15), 13, 0, TAU, 24, Color("fff2bd"), 2)
		draw_polyline(PackedVector2Array([Vector2(8, 15), Vector2(13, 20), Vector2(22, 10)]), Color("fff9db"), 3)

class PawStamp extends Control:
	func _draw() -> void:
		var ink := Color.WHITE
		draw_circle(Vector2(12, 17), 5, ink)
		for point: Vector2 in [Vector2(5, 10), Vector2(10, 6), Vector2(16, 7), Vector2(20, 12)]:
			draw_circle(point, 2.7, ink)

class SpeechBubble extends PanelContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		# An opaque tail joins the panel and points toward the owner's face.
		var points := PackedVector2Array([Vector2(3, size.y - 38), Vector2(-17, size.y - 10), Vector2(3, size.y - 16)])
		draw_colored_polygon(points, Color("fff8df"))
		draw_polyline(points, Color("bca071"), 2.0)

func _ready() -> void:
	if not SocialAuth.has_valid_session():
		get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
		return
	background = BOOK_ART.load_background()
	if background == null:
		push_error("Owner book background could not be read")
		get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)
		return
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 34
	theme = ui_theme
	# One full-viewport illustration, independent of the uniformly scaled UI.
	var paper := _image(background)
	paper.name = "BookBackground"
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	var material := ShaderMaterial.new()
	material.shader = BOOK_SHADER
	paper.material = material
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.size = LAYOUT_SIZE
	add_child(design)
	_build_left_page()
	_build_right_page()
	var flora := Control.new()
	flora.set_script(FLORA)
	flora.size = DESIGN_SIZE
	design.add_child(flora)
	_build_back_button()
	dialog = MODAL.new()
	add_child(dialog)
	dialog.confirmed.connect(_confirm_cafe)
	dialog.cancelled.connect(func() -> void: pending_profile.clear())
	_select_owner(0)
	SocialAuth.session_changed.connect(_on_session_changed)
	resized.connect(_layout)
	_layout()

func _build_left_page() -> void:
	_text("사장님을 골라요", Rect2(237, 96, 352, 49), 43)
	for index: int in range(OWNERS.size()):
		var button := Button.new()
		button.name = "Owner_" + str(OWNERS[index].id)
		button.position = Vector2(236 + (index % 3) * 120, 161 + (index / 3) * 132)
		button.size = Vector2(108, 119)
		button.toggle_mode = true
		button.accessibility_name = str(OWNERS[index].name)
		button.tooltip_text = str(OWNERS[index].name)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal", _card_style(false))
		button.add_theme_stylebox_override("hover", _card_style(false, true))
		button.add_theme_stylebox_override("pressed", _card_style(true))
		button.add_theme_stylebox_override("focus", _focus_style())
		button.pressed.connect(_select_owner.bind(index))
		design.add_child(button)
		setup_ui.append(button)
		var image := _image(OWNERS[index].texture)
		image.position = Vector2(8, 8)
		image.size = Vector2(92, 103)
		button.add_child(image)
		var mark := CheckMark.new()
		mark.position = Vector2(87, -9)
		mark.size = Vector2(30, 30)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mark)
		cards.append(button)
		marks.append(mark)

func _build_right_page() -> void:
	portrait = _image(OWNERS[0].texture)
	portrait.name = "SelectedOwner"
	portrait.position = Vector2(700, 105)
	portrait.size = Vector2(330, 330)
	design.add_child(portrait)
	setup_ui.append(portrait)
	var greeting := SpeechBubble.new()
	greeting.name = "OwnerSpeechBubble"
	var longest_line: float = 0.0
	for dialogue: String in OWNER_LINES.values():
		for line: String in dialogue.split("\n"):
			longest_line = maxf(longest_line, FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x)
	# Halve the empty width around the longest line, keeping the former center (1034, 146).
	var bubble_width: float = ceilf(longest_line + maxf(28.0, 222.0 - longest_line) * 0.5)
	greeting.position = Vector2(1034.0 - bubble_width * 0.5, 94)
	greeting.custom_minimum_size = Vector2(bubble_width, 104)
	var bubble_style := _paper_style(Color("fff8df"), Color("bca071"), 12, 2)
	bubble_style.content_margin_left = 7
	bubble_style.content_margin_right = 7
	bubble_style.content_margin_top = 9
	bubble_style.content_margin_bottom = 9
	greeting.add_theme_stylebox_override("panel", bubble_style)
	greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(greeting)
	setup_ui.append(greeting)
	owner_line = Label.new()
	owner_line.name = "OwnerLine"
	owner_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Shape the complete line first so centered text does not jump while appearing.
	owner_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	owner_line.add_theme_font_size_override("font_size", 28)
	owner_line.add_theme_color_override("font_color", Color("64402a"))
	owner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greeting.add_child(owner_line)
	owner_caption = _text("", Rect2(707, 427, 370, 27), 26)
	# Let the font's real minimum height determine the input's position.
	var name_form := VBoxContainer.new()
	name_form.position = Vector2(704, 467)
	name_form.size.x = 373
	name_form.add_theme_constant_override("separation", 8)
	design.add_child(name_form)
	setup_ui.append(name_form)
	var name_label := Label.new()
	name_label.text = "찻집 이름을 정해주세요!"
	name_label.custom_minimum_size.y = 40
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color("543921"))
	name_form.add_child(name_label)
	name_input = LineEdit.new()
	name_input.name = "CafeName"
	name_input.custom_minimum_size = Vector2(373, 57)
	name_input.placeholder_text = "도트한잔"
	name_input.accessibility_name = "가게 이름, 닉네임"
	name_input.add_theme_font_size_override("font_size", 34)
	name_input.add_theme_color_override("font_color", Color("513720"))
	name_input.add_theme_color_override("font_placeholder_color", Color("a78e62"))
	name_input.add_theme_color_override("caret_color", Color("815b30"))
	var input_style := _paper_style(Color("fff8db"), Color("b29965"), 10, 2)
	input_style.content_margin_right = 112
	var input_focus := _paper_style(Color("fffbe9"), Color("d5a034"), 10, 3)
	input_focus.content_margin_right = 112
	name_input.add_theme_stylebox_override("normal", input_style)
	name_input.add_theme_stylebox_override("focus", input_focus)
	name_form.add_child(name_input)
	name_check_button = Button.new()
	name_check_button.name = "CheckCafeName"
	name_check_button.text = "중복확인"
	name_check_button.accessibility_name = "찻집 이름 중복확인"
	# Keep the LineEdit's IME alive until the explicit check captures its visible text.
	name_check_button.focus_mode = Control.FOCUS_NONE
	name_check_button.mouse_filter = Control.MOUSE_FILTER_STOP
	name_check_button.add_theme_font_size_override("font_size", 26)
	name_check_button.add_theme_color_override("font_color", Color("573619"))
	name_check_button.add_theme_color_override("font_disabled_color", Color("a58b63"))
	var check_style := _paper_style(Color("f5dfab"), Color("bd985a"), 7, 1)
	check_style.content_margin_left = 6
	check_style.content_margin_right = 6
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		name_check_button.add_theme_stylebox_override(state, check_style)
	name_input.add_child(name_check_button)
	name_check_button.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	name_check_button.offset_left = -104
	name_check_button.offset_right = -8
	name_check_button.offset_top = 6
	name_check_button.offset_bottom = -6
	name_check_button.disabled = true
	name_check_button.pressed.connect(_check_cafe_name)
	name_check_hint = RichTextLabel.new()
	name_check_hint.name = "CafeNameResult"
	name_check_hint.custom_minimum_size = Vector2(373, 28)
	name_check_hint.bbcode_enabled = true
	name_check_hint.fit_content = true
	name_check_hint.scroll_active = false
	name_check_hint.add_theme_font_override("normal_font", FONT)
	name_check_hint.add_theme_font_override("bold_font", FONT)
	name_check_hint.add_theme_font_size_override("normal_font_size", 22)
	name_check_hint.add_theme_font_size_override("bold_font_size", 24)
	name_check_hint.add_theme_color_override("default_color", Color("795b36"))
	name_check_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_form.add_child(name_check_hint)
	name_input.text_changed.connect(_on_cafe_name_changed)
	start_button = Button.new()
	start_button.name = "StartPreview"
	start_button.text = "시작"
	start_button.size = Vector2(136, 58)
	start_button.disabled = true
	start_button.add_theme_font_size_override("font_size", 35)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		start_button.add_theme_color_override(color_name, Color.WHITE)
	start_button.add_theme_stylebox_override("normal", _bookmark_style(Color("426b48")))
	start_button.add_theme_stylebox_override("hover", _bookmark_style(Color("527e55")))
	start_button.add_theme_stylebox_override("pressed", _bookmark_style(Color("315438")))
	start_button.add_theme_stylebox_override("hover_pressed", _bookmark_style(Color("315438")))
	start_button.add_theme_stylebox_override("disabled", _bookmark_style(Color("526353")))
	start_button.add_theme_stylebox_override("focus", _bookmark_style(Color.TRANSPARENT, 3.0))
	add_child(start_button)
	setup_ui.append(start_button)
	start_button.pressed.connect(_start_cafe)
	var paw := PawStamp.new()
	paw.position = Vector2(18, 15)
	paw.size = Vector2(26, 26)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.add_child(paw)
	# The existing confirmation/save/transition handler is unchanged by the style.

func _on_cafe_name_changed(_value: String) -> void:
	name_revision += 1
	checked_cafe_name = ""
	checked_name_input = ""
	name_check_hint.clear()
	name_check_button.text = "확인 중…" if name_check_busy else "중복확인"
	name_preview = _name_candidate()
	_refresh_name_controls()

func _name_candidate() -> String:
	var candidate: String = name_input.text
	if name_input.has_ime_text() and DisplayServer.has_feature(DisplayServer.FEATURE_IME):
		candidate = candidate.insert(name_input.get_caret_column(), DisplayServer.ime_get_text())
	return candidate

func _name_characters_valid(value: String) -> bool:
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122): continue
		if (code >= 0x1100 and code <= 0x11FF) or (code >= 0x3130 and code <= 0x318F): continue
		if (code >= 0xA960 and code <= 0xA97F) or (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0xD7B0 and code <= 0xD7FF): continue
		return false
	return true

func _refresh_name_controls() -> void:
	var candidate: String = _name_candidate()
	var valid: bool = not candidate.is_empty() and _name_characters_valid(candidate)
	name_check_button.disabled = entering_cafe or not saved_profile.is_empty() or name_check_busy or not valid
	start_button.disabled = entering_cafe or BookTransition.busy or name_check_busy or not valid or checked_cafe_name.is_empty() or checked_name_input != name_input.text or name_input.has_ime_text() or not SocialAuth.has_valid_session()
	if not candidate.is_empty() and not _name_characters_valid(candidate): _show_name_format_hint()

func _show_name_format_hint() -> void:
	name_check_hint.add_theme_color_override("default_color", Color("795b36"))
	name_check_hint.text = "찻집 이름은 [b][color=#315b35]한글[/color][/b], [b][color=#315b35]영문[/color][/b](대·소문자), [b][color=#315b35]숫자[/color][/b]만 쓸 수 있어요."

func _check_cafe_name() -> void:
	if name_check_busy or entering_cafe: return
	# Snapshot the displayed name BEFORE focus/IME teardown (the final syllable may
	# still be preedit text). Insert preedit at the caret, including edits in the middle.
	var candidate: String = _name_candidate()
	var candidate_caret: int = name_input.get_caret_column() + candidate.length() - name_input.text.length()
	name_check_busy = true
	checked_cafe_name = ""
	checked_name_input = ""
	# One normal end-edit path commits the IME and hides a mobile keyboard.
	name_input.unedit()
	name_input.release_focus()
	# Lock only while the pending OS input notifications settle, not during the API request.
	name_input.editable = false
	_refresh_name_controls()
	name_check_button.text = "확인 중…"
	await get_tree().process_frame
	if not is_inside_tree(): return
	# Restore this click's snapshot only if OS teardown dropped/duplicated preedit.
	# Never rewrite the value/caret on ordinary keystrokes or from a server response.
	if name_input.text != candidate:
		name_input.text = candidate
		name_input.set_caret_column(candidate_caret)
		_on_cafe_name_changed(candidate)
	name_preview = name_input.text
	name_input.editable = true
	if candidate.is_empty() or not _name_characters_valid(candidate):
		name_check_busy = false
		name_check_button.text = "중복확인"
		_refresh_name_controls()
		if candidate.is_empty(): _set_name_check_hint("찻집 이름을 먼저 적어 주세요!", false)
		else: _show_name_format_hint()
		return
	var revision: int = name_revision
	checked_cafe_name = ""
	_set_name_check_hint("같은 이름의 찻집이 있는지 살펴볼게요.", false)
	var result: Dictionary = await SocialAuth.check_cafe_name(candidate)
	if not is_inside_tree(): return
	name_check_busy = false
	name_check_button.text = "중복확인"
	_refresh_name_controls()
	# Never accept a response for a name that changed, even if edited back to the same text.
	if revision != name_revision or name_input.text != candidate or name_input.has_ime_text():
		if _name_characters_valid(_name_candidate()): _set_name_check_hint("이름이 바뀌었어요. 다시 확인해 주세요!", false)
		return
	if result.has("error"):
		var message: String = "연결이 잠시 쉬고 있어요. 다시 확인해 주세요."
		if result.error == "invalid_cafe_name":
			if result.get("reason") == "invalid_characters":
				_show_name_format_hint()
				return
			message = "이름은 64글자 안으로 지어 주세요." if result.get("reason") == "too_long" else "이름을 다시 살펴봐 주세요."
		elif result.error == "too_many_attempts": message = "잠깐 쉬었다가 다시 확인해 볼까요?"
		elif result.error == "server_update_required": message = "이름 확인을 위해 서버를 새로 열어 주세요."
		elif result.error in ["session_expired", "session_changed"]: message = "로그인을 다시 확인하고 있어요."
		_set_name_check_hint(message, false)
		return
	if result.available:
		checked_cafe_name = str(result.cafe_name)
		checked_name_input = candidate
		_set_name_check_hint("이 이름, 사용할 수 있어요!", true)
		_refresh_name_controls()
	else:
		_set_name_check_hint("이미 문을 연 찻집 이름이에요. 다른 이름은 어때요?", false)

func _set_name_check_hint(value: String, success: bool) -> void:
	name_check_hint.clear()
	name_check_hint.add_text(value)
	name_check_hint.add_theme_color_override("default_color", Color("48703b") if success else Color("8b593b"))

func _start_cafe() -> void:
	if start_button.disabled or entering_cafe or BookTransition.busy or EntryTransition.busy or dialog.visible: return
	if not SocialAuth.has_valid_session() or checked_name_input != name_input.text or name_input.has_ime_text(): return
	if not saved_profile.is_empty():
		BookTransition.enter(self, saved_profile)
		return
	var owner_name: String = ""
	for owner: Dictionary in OWNERS:
		if str(owner.id) == selected_owner_id: owner_name = str(owner.name)
	pending_profile = {"owner_character_id": selected_owner_id, "cafe_name": checked_cafe_name}
	dialog.show_confirmation("이대로 문을 열까요?", "사장님: %s\n가게이름: %s\n\n한번 정하면 바꿀 수 없어요." % [owner_name, checked_cafe_name])

func _confirm_cafe() -> void:
	if pending_profile.is_empty() or entering_cafe: return
	var confirmed: Dictionary = pending_profile.duplicate()
	pending_profile.clear()
	if str(confirmed.owner_character_id) != selected_owner_id or str(confirmed.cafe_name) != checked_cafe_name or checked_name_input != name_input.text: return
	entering_cafe = true
	name_input.editable = false
	_refresh_name_controls()
	_set_name_check_hint("찻집 이름을 책에 적고 있어요…", true)
	var result: Dictionary = await SocialAuth.setup_cafe(str(confirmed.owner_character_id), str(confirmed.cafe_name))
	if not is_inside_tree() or not SocialAuth.has_valid_session(): return
	if result.has("player"):
		saved_profile = result.player
		BookTransition.enter(self, saved_profile)
		return
	entering_cafe = false
	name_input.editable = true
	var error: String = str(result.get("error", "server_unavailable"))
	if error == "session_changed" or error == "session_expired":
		_go_back(true)
		return
	if error == "cafe_name_taken":
		checked_cafe_name = ""
		checked_name_input = ""
	_refresh_name_controls()
	_set_name_check_hint("저장을 마치지 못했어요. 안내를 확인해 주세요.", false)
	dialog.title = "잠깐만요, 사장님"
	dialog.dialog_text = "저장을 확인하지 못했어요. 같은 이름으로 다시 눌러 주세요."
	if error == "cafe_name_taken": dialog.dialog_text = "그새 같은 이름의 찻집이 문을 열었어요. 다른 이름을 골라 주세요."
	if error == "profile_already_set": dialog.dialog_text = "이미 정해 둔 사장님과 찻집이 있어요. 뒤로 나가 다시 들어와 주세요."
	dialog.ok_button_text = "알겠어요"
	dialog.popup_centered()

func _hide_setup_ui() -> void:
	entering_cafe = true
	name_input.unedit()
	name_input.release_focus()
	for control: Control in setup_ui: control.hide()
	# The original illustration, botanical shader and outside leaves keep moving.

func _restore_setup_ui() -> void:
	entering_cafe = false
	for control: Control in setup_ui: control.show()
	name_input.editable = saved_profile.is_empty()
	_refresh_name_controls()

func _show_cafe_entry_error(_error: String) -> void:
	dialog.title = "책장이 잠깐 멈췄어요"
	dialog.dialog_text = "찻집 문을 다시 열어 볼까요?"
	dialog.ok_button_text = "다시 해볼게요"
	dialog.popup_centered()

func _build_back_button() -> void:
	back_button = Button.new()
	back_button.name = "BackToEntry"
	back_button.text = "‹  뒤로"
	back_button.accessibility_name = "돌아가기, 터치해서 들어가요 화면"
	back_button.size = Vector2(114, 57)
	back_button.add_theme_font_size_override("font_size", 32)
	back_button.add_theme_color_override("font_color", Color("fff2cd"))
	var panel: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres").duplicate()
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	panel.set_corner_radius_all(14)
	back_button.add_theme_stylebox_override("normal", panel)
	back_button.add_theme_stylebox_override("hover", panel)
	back_button.add_theme_stylebox_override("pressed", panel)
	back_button.add_theme_stylebox_override("focus", _focus_style())
	back_button.pressed.connect(_go_back)
	add_child(back_button)
	setup_ui.append(back_button)

func _select_owner(index: int) -> void:
	if entering_cafe or dialog.visible or not saved_profile.is_empty(): return
	selected_owner_id = str(OWNERS[index].id)
	portrait.texture = OWNERS[index].texture
	owner_caption.text = '"%s" 사장님' % str(OWNERS[index].name)
	owner_line.text = str(OWNER_LINES[selected_owner_id])
	owner_line.visible_characters = 0
	line_elapsed = 0.0
	line_characters = owner_line.get_total_character_count()
	line_typing = true
	for card_index: int in range(cards.size()):
		cards[card_index].set_pressed_no_signal(card_index == index)
		marks[card_index].visible = card_index == index

func _go_back(force: bool = false) -> void:
	if (entering_cafe or dialog.visible) and not force: return
	# Scene-local selection/name disappear; authentication and account data stay untouched.
	name_input.release_focus()
	get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)

func _on_session_changed(authenticated: bool) -> void:
	if not authenticated: _go_back(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if name_input.has_focus(): name_input.release_focus()
		else: _go_back()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var preview: String = _name_candidate()
	if preview != name_preview:
		name_preview = preview
		checked_cafe_name = ""
		checked_name_input = ""
		name_revision += 1
		name_check_hint.clear()
		_refresh_name_controls()
	# A new Korean preedit is a change too, even before text_changed is committed.
	if not checked_cafe_name.is_empty() and name_input.has_ime_text():
		checked_cafe_name = ""
		checked_name_input = ""
		name_revision += 1
		name_check_hint.clear()
		_refresh_name_controls()
	# Initial dialogue waits until the entrance leaves have revealed the book.
	# One local clock is reset on selection: no old timer/tween can finish later.
	if line_typing and not EntryTransition.busy:
		line_elapsed += delta
		owner_line.visible_characters = mini(line_characters, int(line_elapsed / LINE_CHARACTER_SECONDS))
		if owner_line.visible_characters >= line_characters:
			line_typing = false
	# Desktop display servers do not support this call and would log every frame.
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return
	var height: int = DisplayServer.virtual_keyboard_get_height()
	if height != keyboard_height:
		keyboard_height = height
		_layout()

func _layout() -> void:
	if design == null: return
	var available := Rect2(Vector2.ZERO, size)
	var pixels: Vector2i = DisplayServer.window_get_size()
	if OS.get_name() in ["Android", "iOS"] and pixels.x > 0 and pixels.y > 0:
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var ratio: Vector2 = size / Vector2(pixels)
		if safe.size.x > 0 and safe.size.y > 0:
			available = Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio).intersection(available)
		if keyboard_height > 0:
			available.size.y = maxf(180.0, minf(available.size.y, size.y - float(keyboard_height) * ratio.y - available.position.y))
	var factor: float = minf(available.size.x / LAYOUT_SIZE.x, available.size.y / LAYOUT_SIZE.y)
	design.scale = Vector2.ONE * factor
	design.position = available.position + (available.size - LAYOUT_SIZE * factor) * 0.5
	# Background fills the viewport: align to its book edge, not the UI's fitted plane.
	start_button.scale = Vector2.ONE * factor
	var button_size: Vector2 = start_button.size * factor
	var center := Vector2(size.x * 0.895, size.y * 0.5)
	center.x = clampf(center.x, available.position.x + button_size.x * 0.5 + 8.0, available.end.x - button_size.x * 0.5 - 8.0)
	center.y = clampf(center.y, available.position.y + button_size.y * 0.5 + 8.0, available.end.y - button_size.y * 0.5 - 8.0)
	start_button.position = center - button_size * 0.5
	back_button.position = available.position + Vector2(16, 14)

func _image(texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _text(value: String, rect: Rect2, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("543921"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(label)
	setup_ui.append(label)
	return label

func _bookmark_style(color: Color, width: float = 2.0) -> StyleBox:
	var style: StyleBox = BOOKMARK_STYLE.new()
	style.set("fill_color", color)
	style.set("border_width", width)
	# Text stays between the leading paw and the transparent right-hand notch.
	style.content_margin_left = 40
	style.content_margin_right = 26
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _paper_style(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

func _card_style(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var background := Color("f8e9c7") if not hover else Color("fff4d6")
	var style := _paper_style(background, Color("dba52d") if selected else Color("ba9864"), 7, 3 if selected else 2)
	style.shadow_color = Color(0.35, 0.2, 0.08, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style

func _focus_style() -> StyleBoxFlat:
	return _paper_style(Color.TRANSPARENT, Color("b7892d"), 8, 3)
