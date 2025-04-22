extends Camera2D
class_name PlayerCamera

# Camera follow
@export var target: Node2D
@export var follow_speed: float = 5.0
@export var look_ahead: float = 100.0
@export var look_ahead_speed: float = 3.0

# Screen shake
@export var max_shake_offset: Vector2 = Vector2(20, 15)
@export var max_shake_roll: float = 0.1
@export var shake_decay: float = 3.0
@export var shake_trauma_power: float = 2.0

# Hit effects
@export var hit_zoom_amount: float = 0.85
@export var hit_zoom_duration: float = 0.3
@export var hit_shake_amount: float = 0.5
@export var hit_flash_color: Color = Color(1, 0.2, 0.2, 0.3)
@export var hit_flash_duration: float = 0.15

# Attack effectsaaa
@export var attack_zoom_amount: float = 1.1
@export var attack_zoom_duration: float = 0.2
@export var hit_stop_time: float = 0.1

# Camera boundaries
@export var boundary_shape: RectangleShape2D
@export var boundary_collision: CollisionShape2D

var trauma: float = 0.0
var noise_y: float = 0.0
var current_look_ahead: Vector2 = Vector2.ZERO
var base_zoom: Vector2 = Vector2.ONE

@onready var noise = FastNoiseLite.new()
@onready var boundary_area = Area2D.new()
@onready var flash_rect = ColorRect.new()
@onready var canvas_layer = CanvasLayer.new()
@onready var shake_container := Node2D.new()

func _ready():
	# Setup noise
	noise.seed = randi()
	noise.frequency = 0.5
	base_zoom = zoom

	# Setup boundary
	if boundary_shape:
		setup_boundaries()

	# Create Shake Container
	add_child(shake_container)
	for child in get_children():
		if child != shake_container:
			shake_container.add_child(child)

	# Setup flash effect
	setup_flash_effect()

func setup_flash_effect():
	canvas_layer.layer = 100
	add_child(canvas_layer)

	flash_rect.color = Color.TRANSPARENT
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(flash_rect)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	flash_rect.size = get_viewport_rect().size

func _process(delta):
	if !target:
		return

	update_follow(delta)
	update_shake(delta)
	enforce_boundaries()

func update_follow(delta):
	var target_pos = target.global_position
	var look_ahead_dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()

	var desired_look_ahead = look_ahead_dir * look_ahead
	current_look_ahead = current_look_ahead.lerp(desired_look_ahead, look_ahead_speed * delta)

	var final_target_pos = target_pos + current_look_ahead
	global_position = global_position.lerp(final_target_pos, follow_speed * delta)

func update_shake(delta):
	if trauma > 0:
		trauma = max(trauma - shake_decay * delta, 0)
		apply_shake()
	else:
		shake_container.position = Vector2.ZERO
		shake_container.rotation = 0.0

func apply_shake():
	var amount = pow(trauma, shake_trauma_power)
	noise_y += 1.0

	var shake_offset = Vector2(
		noise.get_noise_2d(noise.seed, noise_y),
		noise.get_noise_2d(noise.seed * 2, noise_y)
	) * max_shake_offset * amount

	var shake_rotation = noise.get_noise_2d(noise.seed * 3, noise_y) * max_shake_roll * amount

	shake_container.position = shake_offset
	shake_container.rotation = shake_rotation

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func setup_boundaries():
	boundary_area.name = "CameraBoundary"
	boundary_area.collision_layer = 0
	boundary_area.collision_mask = 0

	if !boundary_collision:
		boundary_collision = CollisionShape2D.new()
		boundary_collision.shape = boundary_shape
		boundary_area.add_child(boundary_collision)

	get_parent().add_child(boundary_area)
	boundary_area.global_position = global_position

func enforce_boundaries():
	if !boundary_shape:
		return

	var boundary_rect = Rect2(
		boundary_area.global_position - boundary_shape.size / 2,
		boundary_shape.size
	)

	var viewport = get_viewport_rect().size
	var camera_rect = Rect2(
		global_position - viewport * zoom / 2,
		viewport * zoom
	)

	if camera_rect.position.x < boundary_rect.position.x:
		global_position.x += boundary_rect.position.x - camera_rect.position.x
	if camera_rect.position.y < boundary_rect.position.y:
		global_position.y += boundary_rect.position.y - camera_rect.position.y
	if camera_rect.end.x > boundary_rect.end.x:
		global_position.x -= camera_rect.end.x - boundary_rect.end.x
	if camera_rect.end.y > boundary_rect.end.y:
		global_position.y -= camera_rect.end.y - boundary_rect.end.y

func apply_hit_effect():
	add_trauma(hit_shake_amount)
	zoom_to(hit_zoom_amount, hit_zoom_duration)
	flash_screen(hit_flash_color, hit_flash_duration)

func apply_attack_effect(attack_zoom_amount, attack_zoom_duration, hit_stop_time):
	zoom_to(attack_zoom_amount, attack_zoom_duration)
	apply_hit_pause(hit_stop_time)

func zoom_to(amount: float, duration: float):
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", base_zoom * amount, duration * 0.5)
	tween.tween_property(self, "zoom", base_zoom, duration * 0.5)

func flash_screen(color: Color, duration: float):
	if flash_rect.has_meta("active_tween"):
		var existing_tween = flash_rect.get_meta("active_tween")
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()

	var tween = create_tween()
	flash_rect.set_meta("active_tween", tween)

	flash_rect.color = color
	tween.tween_property(flash_rect, "color:a", 0.0, duration)

func apply_hit_pause(duration: float = 0.1):
	Engine.time_scale = 0.01  # Nearly frozen
	await get_tree().create_timer(duration * 0.02).timeout
	Engine.time_scale = 1.0
	
func _on_player_took_damage():
	apply_hit_effect()
