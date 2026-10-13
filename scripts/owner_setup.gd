extends Control

const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const BOOK_ART: Script = preload("res://scripts/owner_book_art.gd")
const BOOK_SHADER: Shader = preload("res://shaders/owner_book.gdshader")
const FLORA: Script = preload("res://scripts/owner_book_flora.gd")
const DESIGN_SIZE := Vector2(1280, 720)
# Include a footer below the book without changing either page's coordinates.
const LAYOUT_SIZE := Vector2(1280, 752)
const OWNERS: Array[Dictionary] = [
	{"id": "human-male", "name": "사람 사장님 · 남자", "texture": preload("res://assets/characters/owners/human-male-idle.png")},
	{"id": "human-female", "name": "사람 사장님 · 여자", "texture": preload("res://assets/characters/owners/human-female-idle.png")},
	{"id": "cat-ginger", "name": "치즈냥이 사장님", "texture": preload("res://assets/characters/owners/cat-ginger-idle.png")},
	{"id": "cat-black", "name": "검은 냥이 사장님", "texture": preload("res://assets/characters/owners/cat-black-idle.png")},
	{"id": "cat-white-gray", "name": "흰색·회색 냥이 사장님", "texture": preload("res://assets/characters/owners/cat-white-gray-idle.png")},
	{"id": "fox-orange", "name": "주황 여우 사장님", "texture": preload("res://assets/characters/owners/fox-orange-idle.png")},
	{"id": "fox-white", "name": "설원 여우 사장님", "texture": preload("res://assets/characters/owners/fox-white-idle.png")},
	{"id": "rabbit-white", "name": "흰 토끼 사장님", "texture": preload("res://assets/characters/owners/rabbit-white-idle.png")},
	{"id": "rabbit-light-brown", "name": "연갈색 토끼 사장님", "texture": preload("res://assets/characters/owners/rabbit-light-brown-idle.png")},
]
var selected_owner_id: String = "rabbit-white"
var design: Control
var portrait: TextureRect
var owner_caption: Label
var name_input: LineEdit
var start_button: Button
var back_button: Button
var cards: Array[Button] = []
var marks: Array[Control] = []
var keyboard_height: int = 0
var background: Texture2D

class CheckMark extends Control:
	func _draw() -> void:
		draw_circle(Vector2(15, 15), 14, Color("dfa933"))
		draw_arc(Vector2(15, 15), 13, 0, TAU, 24, Color("fff2bd"), 2)
		draw_polyline(PackedVector2Array([Vector2(8, 15), Vector2(13, 20), Vector2(22, 10)]), Color("fff9db"), 3)

class PawStamp extends Control:
	func _draw() -> void:
		var ink := Color("bb7e30")
		draw_circle(Vector2(12, 17), 5, ink)
		for point: Vector2 in [Vector2(5, 10), Vector2(10, 6), Vector2(16, 7), Vector2(20, 12)]:
			draw_circle(point, 2.7, ink)

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
	# Cover the extra sides of long phone screens without stretching the book UI.
	var surround := _image(background)
	surround.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(surround)
	surround.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.size = LAYOUT_SIZE
	add_child(design)
	var paper := _image(background)
	paper.size = DESIGN_SIZE
	var material := ShaderMaterial.new()
	material.shader = BOOK_SHADER
	paper.material = material
	design.add_child(paper)
	_build_left_page()
	_build_right_page()
	var flora := Control.new()
	flora.set_script(FLORA)
	flora.size = DESIGN_SIZE
	design.add_child(flora)
	_build_back_button()
	_select_owner(7)
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
	portrait = _image(OWNERS[7].texture)
	portrait.name = "SelectedOwner"
	portrait.position = Vector2(700, 105)
	portrait.size = Vector2(330, 330)
	design.add_child(portrait)
	var greeting := PanelContainer.new()
	greeting.position = Vector2(986, 173)
	greeting.size = Vector2(102, 91)
	greeting.add_theme_stylebox_override("panel", _paper_style(Color(1, 0.96, 0.82, 0.7), Color("dfc89d"), 8, 1))
	greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(greeting)
	var hello := Label.new()
	hello.text = "처음 뵙네요,\n사장님!"
	hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hello.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hello.add_theme_font_size_override("font_size", 28)
	hello.add_theme_color_override("font_color", Color("64402a"))
	greeting.add_child(hello)
	owner_caption = _text("", Rect2(707, 427, 370, 27), 26)
	# Let the font's real minimum height determine the input's position.
	var name_form := VBoxContainer.new()
	name_form.position = Vector2(704, 455)
	name_form.size.x = 373
	name_form.add_theme_constant_override("separation", 8)
	design.add_child(name_form)
	var name_label := Label.new()
	name_label.text = "가게 이름"
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
	name_input.add_theme_stylebox_override("normal", _paper_style(Color("fff8db"), Color("b29965"), 10, 2))
	name_input.add_theme_stylebox_override("focus", _paper_style(Color("fffbe9"), Color("d5a034"), 10, 3))
	name_form.add_child(name_input)
	start_button = Button.new()
	start_button.name = "StartPreview"
	start_button.text = "시작할게요"
	start_button.position = Vector2((LAYOUT_SIZE.x - 294.0) * 0.5, 676)
	start_button.size = Vector2(294, 55)
	start_button.add_theme_font_size_override("font_size", 35)
	start_button.add_theme_color_override("font_color", Color("573619"))
	start_button.add_theme_stylebox_override("normal", _paper_style(Color("ffe6a8"), Color("9b6d35"), 12, 2))
	start_button.add_theme_stylebox_override("hover", _paper_style(Color("ffedbd"), Color("b68135"), 12, 2))
	start_button.add_theme_stylebox_override("pressed", _paper_style(Color("efd191"), Color("9b6d35"), 12, 2))
	start_button.add_theme_stylebox_override("focus", _focus_style())
	design.add_child(start_button)
	var paw := PawStamp.new()
	paw.position = Vector2(244, 14)
	paw.size = Vector2(26, 26)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button.add_child(paw)
	# Intentionally no pressed/text_submitted handler, validation, API write or next scene.

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

func _select_owner(index: int) -> void:
	selected_owner_id = str(OWNERS[index].id)
	portrait.texture = OWNERS[index].texture
	owner_caption.text = str(OWNERS[index].name)
	for card_index: int in range(cards.size()):
		cards[card_index].set_pressed_no_signal(card_index == index)
		marks[card_index].visible = card_index == index

func _go_back() -> void:
	# Scene-local selection/name disappear; authentication and account data stay untouched.
	name_input.release_focus()
	get_tree().change_scene_to_file(SocialAuth.LOGIN_SCENE)

func _on_session_changed(authenticated: bool) -> void:
	if not authenticated: _go_back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if name_input.has_focus(): name_input.release_focus()
		else: _go_back()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
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
	return label

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
