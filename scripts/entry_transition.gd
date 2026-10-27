extends CanvasLayer

signal covered
signal finished

const LEAF_SHADER: Shader = preload("res://shaders/entry_leaf.gdshader")
const CANOPY_SHADER: Shader = preload("res://shaders/entry_canopy.gdshader")
const OWNER_SETUP_SCENE: String = "res://scenes/owner_setup.tscn"
const GAME_SCENE: String = "res://scenes/game.tscn"
const COLUMNS: int = 7
const ROWS: int = 5
var busy: bool = false
var progress: float = 0.0
var opening: bool = false
var fully_covered: bool = false
var surface: Control
var canopy: ColorRect
var canopy_material: ShaderMaterial
var leaves: Array[ColorRect] = []
var motion: Tween

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Control.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	canopy = ColorRect.new()
	canopy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canopy_material = ShaderMaterial.new()
	canopy_material.shader = CANOPY_SHADER
	canopy.material = canopy_material
	surface.add_child(canopy)
	canopy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in range(COLUMNS * ROWS):
		var leaf := ColorRect.new()
		leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = LEAF_SHADER
		material.set_shader_parameter("tint", sin(float(index) * 7.3))
		leaf.material = material
		surface.add_child(leaf)
		leaves.append(leaf)
	surface.hide()
	set_process(false)
	set_process_input(false)

func _input(_event: InputEvent) -> void:
	# Keyboard, mouse and touch cannot reach either scene during the transition.
	if busy: get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_leaves()

func _update_leaves() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var cell := viewport_size / Vector2(COLUMNS, ROWS)
	var coverage: float = clampf((progress - 0.78) / 0.22, 0.0, 1.0)
	if opening: coverage = 1.0 - clampf(progress / 0.24, 0.0, 1.0)
	canopy_material.set_shader_parameter("coverage", coverage)
	for index: int in range(leaves.size()):
		var leaf: ColorRect = leaves[index]
		var seed_value: float = float(index)
		var delay: float = fmod(seed_value * 0.137, 0.22)
		var travel: float = clampf((progress - delay) / (1.0 - delay), 0.0, 1.0)
		var ease: float = travel * travel * (3.0 - 2.0 * travel)
		var resting := Vector2((float(index % COLUMNS) + 0.5) * cell.x, (floorf(seed_value / float(COLUMNS)) + 0.5) * cell.y)
		var distant := viewport_size * Vector2(0.46, 0.25) + Vector2(sin(seed_value * 3.1) * 80.0, cos(seed_value * 2.7) * 35.0)
		var width: float = maxf(cell.x, cell.y) * 3.0
		var position_now: Vector2 = distant.lerp(resting, ease)
		var leaf_width: float = lerpf(4.0, width, ease * ease)
		var angle: float = sin(seed_value * 2.9) * 0.65
		if opening:
			var destination := resting + Vector2(viewport_size.x * 1.6, -viewport_size.y * (1.0 + fmod(seed_value * 0.17, 0.6)))
			position_now = resting.lerp(destination, ease)
			leaf_width = width * lerpf(1.0, 0.65, ease)
			angle += ease * 1.3
		else:
			angle += sin(travel * 6.0 + seed_value) * sin(travel * PI) * 0.65
		position_now += Vector2(sin(travel * 8.0 + seed_value) * 60.0, cos(travel * 7.0 + seed_value) * 28.0) * sin(travel * PI)
		leaf.size = Vector2(leaf_width, leaf_width * 0.7)
		leaf.pivot_offset = leaf.size * 0.5
		leaf.position = (position_now - leaf.pivot_offset).snapped(Vector2(2, 2))
		leaf.rotation = angle
		leaf.visible = travel > 0.0 if not opening else travel < 1.0

func _cover() -> void:
	motion = create_tween()
	motion.tween_property(self, "progress", 1.0, 1.65)
	await motion.finished
	fully_covered = true
	_update_leaves()
	covered.emit()

func _reveal() -> void:
	opening = true
	progress = 0.0
	_update_leaves()
	motion = create_tween()
	motion.tween_property(self, "progress", 1.0, 1.25)
	await motion.finished
	surface.hide()
	set_process(false)
	set_process_input(false)
	busy = false
	finished.emit()

func enter(origin: Control) -> void:
	if busy: return
	busy = true
	opening = false
	fully_covered = false
	progress = 0.0
	surface.show()
	set_process(true)
	set_process_input(true)
	_update_leaves()
	_cover()
	# The village continues animating while the request and leaves advance together.
	var account: String = SocialAuth.player_id
	var result: Dictionary = await SocialAuth.fetch_player_profile()
	if not fully_covered: await covered
	# Draw a fully opaque frame BEFORE loading or replacing the current scene.
	await RenderingServer.frame_post_draw
	var error: String = str(result.get("error", ""))
	if not is_instance_valid(origin) or get_tree().current_scene != origin:
		await _reveal()
		return
	if not SocialAuth.has_valid_session() or SocialAuth.player_id != account:
		error = "session_changed"
	if error.is_empty():
		var profile: Dictionary = result.player
		var owner: Variant = profile.get("owner_character_id")
		var cafe: Variant = profile.get("cafe_name")
		var has_owner: bool = owner is String and not owner.strip_edges().is_empty()
		var has_name: bool = cafe is String and not cafe.strip_edges().is_empty()
		var destination: String = GAME_SCENE
		if not has_owner or not has_name: destination = OWNER_SETUP_SCENE
		if destination == GAME_SCENE and not ResourceLoader.exists(destination):
			error = "game_not_ready"
		else:
			if destination == GAME_SCENE: BookTransition.stage_profile(profile, account)
			error = await _change_scene(destination, account)
	# On failure restore the gate underneath the leaves, then show its normal modal.
	if not error.is_empty(): BookTransition.clear_profile()
	if not error.is_empty() and is_instance_valid(origin):
		origin.call("_restore_entry_ui")
	await _reveal()
	if not error.is_empty() and is_instance_valid(origin):
		origin.call("_show_entry_error", error)

func _change_scene(path: String, account: String) -> String:
	var scene: PackedScene = load(path) as PackedScene
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
	# _ready(), container layout and one rendered frame finish while still covered.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return ""
