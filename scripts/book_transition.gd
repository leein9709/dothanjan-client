extends CanvasLayer

signal covered
signal finished

const PAGE_SHADER: Shader = preload("res://shaders/book_page.gdshader")
const CAFE_ART: Script = preload("res://scripts/starter_cafe_art.gd")
const BOOK_ART: Script = preload("res://scripts/owner_book_art.gd")
const GAME_SCENE: String = "res://scenes/game.tscn"
const SOUND_BYTES: String = "res://assets/audio/page-turn.wav.bytes"
const COVER_SECONDS: float = 1.45
const REVEAL_SECONDS: float = 0.95
var busy: bool = false
var progress: float = 0.0
var departure: float = 0.0
var cover_title: Label
var surface: ColorRect
var page_material: ShaderMaterial
var sound: AudioStreamPlayer
var motion: Tween
var _staged_profile: Dictionary = {}
var _frame_time: float = 0.0

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	page_material = ShaderMaterial.new()
	page_material.shader = PAGE_SHADER
	surface.material = page_material
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.hide()
	cover_title = Label.new()
	cover_title.add_theme_font_override("font", preload("res://assets/fonts/Dongle-Regular.ttf"))
	cover_title.add_theme_font_size_override("font_size", 44)
	cover_title.add_theme_color_override("font_color", Color("f5df9a"))
	cover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	cover_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover_title)
	cover_title.hide()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -20.0
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SOUND_BYTES)
	if not bytes.is_empty(): sound.stream = AudioStreamWAV.load_from_buffer(bytes)
	add_child(sound)
	SocialAuth.session_changed.connect(_on_session_changed)
	set_process(false)
	set_process_input(false)

func _input(_event: InputEvent) -> void:
	if busy: get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_frame_time += delta
	if _frame_time < 1.0 / 24.0: return
	_frame_time = fmod(_frame_time, 1.0 / 24.0)
	_update_page()

func _update_page() -> void:
	page_material.set_shader_parameter("pixel_grid", get_viewport().get_visible_rect().size / 2.0)
	page_material.set_shader_parameter("progress", progress)
	page_material.set_shader_parameter("departure", departure)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	cover_title.position = (viewport_size * Vector2(0.36, 0.32 + 1.2 * departure * departure)).round()
	cover_title.size = viewport_size * Vector2(0.285, 0.30)
	var font_size: int = int(clampf(viewport_size.y * 0.061, 18.0, 48.0))
	if cover_title.text.length() > 24: font_size = maxi(16, int(font_size * 0.65))
	cover_title.add_theme_font_size_override("font_size", font_size)

func stage_profile(profile: Dictionary, account: String) -> void:
	# Only server-confirmed profiles are handed across the scene boundary.
	_staged_profile = {"account_id": account, "owner_character_id": str(profile.get("owner_character_id", "")), "cafe_name": str(profile.get("cafe_name", ""))}

func take_profile() -> Dictionary:
	var profile: Dictionary = _staged_profile.duplicate()
	_staged_profile.clear()
	if str(profile.get("account_id", "")) != SocialAuth.player_id or not SocialAuth.has_valid_session(): return {}
	return profile

func clear_profile() -> void:
	_staged_profile.clear()

func _on_session_changed(authenticated: bool) -> void:
	if not authenticated: _staged_profile.clear()

func enter(origin: Control, profile: Dictionary) -> void:
	if busy or EntryTransition.busy or not SocialAuth.has_valid_session(): return
	if not is_instance_valid(origin) or get_tree().current_scene != origin: return
	# The complete room behind the book is prepared before hiding any setup UI.
	var uncovered: Texture2D = BOOK_ART.load_uncovered_background()
	if uncovered == null:
		origin.call("_restore_setup_ui")
		origin.call("_show_cafe_entry_error", "scene_unavailable")
		return
	busy = true
	var account: String = SocialAuth.player_id
	progress = 0.0
	departure = 0.0
	_frame_time = 0.0
	page_material.set_shader_parameter("page_texture", origin.get("background"))
	page_material.set_shader_parameter("backdrop_texture", uncovered)
	cover_title.text = str(profile.get("cafe_name", ""))
	origin.call("_hide_setup_ui")
	surface.show()
	set_process(true)
	set_process_input(true)
	_update_page()
	origin.hide()
	if sound.stream != null: sound.play()
	motion = create_tween()
	motion.tween_property(self, "progress", 1.0, COVER_SECONDS)
	await motion.finished
	progress = 1.0
	_update_page()
	cover_title.show()
	covered.emit()
	# The complete old backdrop stays opaque until the cafe is ready underneath.
	await RenderingServer.frame_post_draw
	var error: String = ""
	if not SocialAuth.has_valid_session() or SocialAuth.player_id != account:
		error = "session_changed"
	elif not is_instance_valid(origin) or get_tree().current_scene != origin:
		error = "scene_changed"
	elif CAFE_ART.load_background() == null:
		error = "scene_unavailable"
	else:
		stage_profile(profile, account)
		error = await _change_scene(account)
	_staged_profile.clear()
	if not error.is_empty() and is_instance_valid(origin) and get_tree().current_scene == origin:
		origin.show()
		origin.call("_restore_setup_ui")
	await _reveal()
	if not error.is_empty() and is_instance_valid(origin) and get_tree().current_scene == origin:
		origin.call("_restore_setup_ui")
		origin.call("_show_cafe_entry_error", error)

func _change_scene(account: String) -> String:
	var scene: PackedScene = load(GAME_SCENE) as PackedScene
	if scene == null: return "scene_unavailable"
	var preview: Node = scene.instantiate()
	if preview == null: return "scene_unavailable"
	var attached: Script = preview.get_script()
	var valid: bool = attached != null and attached.can_instantiate()
	preview.free()
	if not valid: return "scene_unavailable"
	if not SocialAuth.has_valid_session() or SocialAuth.player_id != account: return "session_changed"
	if get_tree().change_scene_to_packed(scene) != OK: return "scene_unavailable"
	await get_tree().scene_changed
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var current: Node = get_tree().current_scene
	if not SocialAuth.has_valid_session() or SocialAuth.player_id != account: return "session_changed"
	if current == null or current.scene_file_path != GAME_SCENE or not current.get("room_ready"): return "scene_unavailable"
	return ""

func _reveal() -> void:
	departure = 0.0
	_update_page()
	motion = create_tween()
	motion.tween_interval(1.0)
	motion.tween_property(self, "departure", 1.0, REVEAL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await motion.finished
	departure = 1.0
	_update_page()
	cover_title.hide()
	surface.hide()
	page_material.set_shader_parameter("page_texture", null)
	page_material.set_shader_parameter("backdrop_texture", null)
	sound.stop()
	set_process(false)
	set_process_input(false)
	busy = false
	finished.emit()
