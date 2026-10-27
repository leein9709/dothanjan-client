extends CharacterBody2D

const WALK_SPEED: float = 192.0
const FOOT_RADIUS: float = 8.0
const MOTION: Script = preload("res://scripts/owner_motion.gd")
const MOTION_SHADER: Shader = preload("res://shaders/owner_motion.gdshader")
var facing := Vector2.DOWN
var portrait: Sprite2D
var _pack: Dictionary = {}
var _animation: String = ""
var _clock: float = 0.0
var _walking: bool = false
var _frame: int = -1

func configure(texture: Texture2D, character_id: String = "") -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = FOOT_RADIUS
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	portrait = Sprite2D.new()
	portrait.texture = texture
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.scale = Vector2.ONE * (112.0 / texture.get_height())
	portrait.offset = Vector2(0.0, -texture.get_height() * 0.45)
	add_child(portrait)
	_pack = MOTION.load_pack(character_id)
	if not _pack.is_empty():
		portrait.centered = false
		portrait.scale = Vector2.ONE * float(_pack.scale)
		var shader_material := ShaderMaterial.new()
		shader_material.shader = MOTION_SHADER
		portrait.material = shader_material
		_set_animation(false)
	queue_redraw()

func _process(delta: float) -> void:
	if _pack.is_empty() or not is_visible_in_tree(): return
	_clock += delta
	_show_frame()

func step(direction: Vector2, delta: float) -> void:
	if direction.length_squared() > 0.0:
		facing = direction.normalized()
	velocity = direction.limit_length() * WALK_SPEED
	var before: Vector2 = position
	move_and_slide()
	_set_animation(position.distance_squared_to(before) > 0.01)

func stop() -> void:
	velocity = Vector2.ZERO
	_set_animation(false)

func _set_animation(walking: bool) -> void:
	if _pack.is_empty(): return
	var next: String = ("walk_" if walking else "idle_") + MOTION.direction_for(facing)
	_walking = walking
	if next == _animation: return
	_animation = next
	_clock = 0.0
	_frame = -1
	_show_frame()

func _show_frame() -> void:
	var frames: Array = _pack.animations[_animation]
	var index: int = int(_clock * (8.0 if _walking else 2.0)) % frames.size()
	if index == _frame: return
	_frame = index
	var pose: Dictionary = frames[index]
	portrait.texture = pose.texture
	portrait.offset = -pose.anchor

func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 18.0, Color(0.07, 0.12, 0.06, 0.28))
