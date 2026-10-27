extends Control

signal enter_cafe_requested
signal message_requested(heading: String, message: String, answer: String)
signal preparation_requested(message: String)

const ART: Script = preload("res://scripts/village_art.gd")
const TERRAIN: Script = preload("res://scripts/village_terrain.gd")
const SCENERY: Script = preload("res://scripts/village_scenery.gd")
const ACTOR: Script = preload("res://scripts/village_actor.gd")
const JOYSTICK: Script = preload("res://ui/village_joystick.gd")
const MINIMAP: Script = preload("res://ui/village_minimap.gd")
const SMOKE: Script = preload("res://scripts/village_smoke.gd")
const FONT: Font = preload("res://assets/fonts/Dongle-Regular.ttf")
const PANEL: StyleBoxFlat = preload("res://ui/styles/tea_panel.tres")
var active: bool = false
var ready_for_walk: bool = false
var world_layer: CanvasLayer
var world: Node2D
var player: ACTOR
var joystick: JOYSTICK
var minimap: MINIMAP
var hint: Button
var instructions: Label
var toast: Label
var smoke: SMOKE
var blocked: Callable
var places: Array[Dictionary] = []
var map_size := Vector2.ONE
var spawn := Vector2.ZERO
var camera_center := Vector2.ZERO
var zoom: float = 1.0
var _camera_height: float = 440.0
var _nearest: Dictionary = {}
var _last_safe := Vector2.ZERO
var _focused: bool = true
var _release_keys: bool = true
var _mobile: bool = false
var _toast_left: float = 0.0

func configure(texture: Texture2D, owner_id: String, catalog: Array, input_blocked: Callable) -> bool:
	var data: Dictionary = ART.load_layout()
	if data.is_empty(): return false
	for id: String in data.assets:
		if ART.load_sprite(id) == null: return false
	var terrain := TERRAIN.new()
	if not terrain.configure(data):
		terrain.free()
		return false
	blocked = input_blocked
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_size = _point(data.world_size)
	_camera_height = float(data.camera_height)
	spawn = _point(data.spawn)
	for item: Dictionary in data.places:
		places.append({"id": str(item.id), "label": str(item.label),
			"kind": str(item.kind), "message": str(item.message), "answer": str(item.answer),
			"point": _point(item.point), "range": float(item.range),
			"hit": Rect2(float(item.hit[0]), float(item.hit[1]),
				float(item.hit[2]), float(item.hit[3]))})
	# CanvasLayer moves only rendering; physics stays in stable map coordinates.
	world_layer = CanvasLayer.new()
	world_layer.layer = -1
	add_child(world_layer)
	world = Node2D.new()
	world_layer.add_child(world)
	world.add_child(terrain)
	_build_boundary()
	var people := Node2D.new()
	people.y_sort_enabled = true
	world.add_child(people)
	for item: Dictionary in data.objects:
		var scenery := SCENERY.new()
		scenery.configure(item, data.assets)
		people.add_child(scenery)
	smoke = SMOKE.new()
	for value: Array in data.chimneys: smoke.chimneys.append(_point(value))
	world.add_child(smoke)
	for item: Dictionary in data.npcs:
		var id: String = str(item.character)
		if id == owner_id: id = str(item.alternate)
		for owner: Dictionary in catalog:
			if str(owner.id) != id: continue
			var neighbor: ACTOR = ACTOR.new()
			neighbor.configure(owner.texture, id)
			neighbor.collision_layer = 0
			neighbor.collision_mask = 0
			neighbor.position = _point(item.point)
			people.add_child(neighbor)
			break
	player = ACTOR.new()
	player.configure(texture, owner_id)
	people.add_child(player)
	_build_hud(data)
	_register_input()
	ready_for_walk = true
	set_active(false)
	return true

func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func _build_boundary() -> void:
	# Only the world perimeter is a boundary. Roads and grass share walkable ground.
	var inset: float = 32.0
	var a := Vector2(inset, inset)
	var b := Vector2(map_size.x - inset, inset)
	var c := map_size - Vector2.ONE * inset
	var d := Vector2(inset, map_size.y - inset)
	var segments := PackedVector2Array([a, b, b, c, c, d, d, a])
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)

func _build_hud(data: Dictionary) -> void:
	_mobile = OS.get_name() in ["Android", "iOS"] or "--preview-touch" in OS.get_cmdline_user_args()
	joystick = JOYSTICK.new()
	joystick.input_blocked = _input_blocked
	joystick.allow_mouse = "--preview-touch" in OS.get_cmdline_user_args()
	add_child(joystick)
	joystick.visible = _mobile
	minimap = MINIMAP.new()
	minimap.roads = data.roads
	minimap.objects = data.objects
	minimap.map_size = map_size
	minimap.places = places
	add_child(minimap)
	hint = Button.new()
	hint.focus_mode = Control.FOCUS_NONE
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_color_override("font_color", Color("fff1cc"))
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = PANEL.duplicate()
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		hint.add_theme_stylebox_override(state, style)
	hint.pressed.connect(_activate_nearest)
	add_child(hint)
	instructions = _label("왼쪽 조이스틱으로 산책 · 가까이 가서 톡!" if _mobile else "WASD / 방향키로 산책 · 가까이 가서 클릭!")
	add_child(instructions)
	toast = _label("")
	add_child(toast)
	toast.hide()

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("fff4d5"))
	label.add_theme_color_override("font_shadow_color", Color("253b2b"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("253b2b"))
	return label

func _register_input() -> void:
	var bindings: Dictionary = {"village_left": [KEY_A, KEY_LEFT], "village_right": [KEY_D, KEY_RIGHT],
		"village_up": [KEY_W, KEY_UP], "village_down": [KEY_S, KEY_DOWN]}
	for action: String in bindings:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func set_active(value: bool) -> void:
	active = value
	visible = value
	if world_layer != null: world_layer.visible = value
	if not ready_for_walk: return
	joystick.set_enabled(false)
	smoke.set_process(value)
	_release_keys = true
	player.stop()
	if value:
		player.position = spawn
		_last_safe = spawn
		_update_camera(0.0, true)
		_update_hint()

func layout_for(safe: Rect2, ui_scale: float) -> void:
	if not ready_for_walk: return
	minimap.size = Vector2(190, 138)
	minimap.scale = Vector2.ONE * ui_scale
	minimap.position = Vector2(safe.end.x - 214 * ui_scale, safe.position.y + 88 * ui_scale)
	joystick.size = Vector2(168, 168)
	joystick.scale = Vector2.ONE * ui_scale
	joystick.position = Vector2(safe.position.x + 28 * ui_scale, safe.end.y - 196 * ui_scale)
	instructions.scale = Vector2.ONE * ui_scale
	instructions.size = Vector2(safe.size.x / ui_scale, 40)
	instructions.position = Vector2(safe.position.x, safe.end.y - 48 * ui_scale)
	toast.scale = Vector2.ONE * ui_scale
	toast.size = Vector2(safe.size.x / ui_scale, 40)
	toast.position = Vector2(safe.position.x, safe.position.y + 125 * ui_scale)
	hint.scale = Vector2.ONE * ui_scale
	hint.size = Vector2(210, 54)
	hint.position = Vector2(safe.get_center().x - 105 * ui_scale, safe.end.y - 112 * ui_scale)
	if active: _update_camera(0.0, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_release_keys = true
		if joystick != null: joystick.set_enabled(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_release_keys = true

func _input_blocked() -> bool:
	return not _focused or (blocked.is_valid() and bool(blocked.call()))

func _physics_process(delta: float) -> void:
	if not active or not ready_for_walk: return
	var keyboard: Vector2 = Input.get_vector("village_left", "village_right", "village_up", "village_down")
	if _input_blocked():
		joystick.set_enabled(false)
		player.stop()
		_release_keys = true
		return
	if _release_keys:
		if keyboard.is_zero_approx(): _release_keys = false
		else: keyboard = Vector2.ZERO
	joystick.set_enabled(_mobile)
	var direction: Vector2 = joystick.direction if not joystick.direction.is_zero_approx() else keyboard
	player.step(direction, delta)
	if Rect2(Vector2(32, 32), map_size - Vector2(64, 64)).has_point(player.position):
		_last_safe = player.position
	else:
		player.position = _last_safe
		player.stop()
	_update_camera(delta)
	_update_hint()
	_toast_left = maxf(0.0, _toast_left - delta)
	toast.visible = _toast_left > 0.0

func _update_camera(delta: float, snap: bool = false) -> void:
	zoom = maxf(size.y / _camera_height, size.x / map_size.x)
	var half_view: Vector2 = size / (2.0 * zoom)
	var target: Vector2 = player.position - Vector2(0, 40)
	target = target.clamp(half_view, map_size - half_view)
	camera_center = target if snap else camera_center.lerp(target, 1.0 - exp(-8.0 * delta))
	camera_center = camera_center.clamp(half_view, map_size - half_view)
	world_layer.transform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), (size * 0.5 - camera_center * zoom).round())
	minimap.player_position = player.position
	minimap.facing = player.facing
	minimap.camera_rect = Rect2(camera_center - half_view, half_view * 2.0)
	minimap.queue_redraw()

func _update_hint() -> void:
	_nearest = {}
	var distance: float = INF
	for place: Dictionary in places:
		var candidate: float = player.position.distance_to(place.point)
		if candidate <= float(place.range) and candidate < distance:
			distance = candidate
			_nearest = place
	hint.visible = not _nearest.is_empty()
	if hint.visible: hint.text = str(_nearest.label) + " ›"

func _unhandled_input(event: InputEvent) -> void:
	if not active or not ready_for_walk or _input_blocked(): return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else: return
	var map_point: Vector2 = world.get_global_transform_with_canvas().affine_inverse() * point
	for place: Dictionary in places:
		var bounds: Rect2 = place.hit
		if not bounds.has_point(map_point): continue
		get_viewport().set_input_as_handled()
		if player.position.distance_to(place.point) <= float(place.range): _activate(place)
		else:
			toast.text = "조금 더 가까이 가볼까요?"
			_toast_left = 2.2
			toast.show()
		return

func _activate_nearest() -> void:
	if active and not _input_blocked() and not _nearest.is_empty(): _activate(_nearest)

func _activate(place: Dictionary) -> void:
	player.stop()
	joystick.set_enabled(false)
	if str(place.kind) == "cafe":
		enter_cafe_requested.emit()
	else:
		message_requested.emit(str(place.label), str(place.message), str(place.answer))
