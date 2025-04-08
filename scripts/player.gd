extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var deceleration_factor: float = 7.0

var last_direction: Vector2 = Vector2(0, 1)
var current_direction: Vector2 = Vector2.ZERO
var is_hit: bool = false
var is_dying: bool = false
var speed_multiplier: float = 1.0

@onready var character_sprite_component = $CharacterSpriteComponent
@onready var flash_timer = $FlashTimer

signal took_damage
signal attacked

func _ready():
	if not has_node("FlashTimer"):
		flash_timer = Timer.new()
		flash_timer.name = "FlashTimer"
		flash_timer.one_shot = false
		add_child(flash_timer)

	flash_timer.timeout.connect(_on_flash_timeout)

	character_sprite_component.set_direction(last_direction)
	character_sprite_component.play_idle()
	
func _physics_process(delta):
	if is_dying:
		return

	handle_movement()
	update_animation_state()
	move_and_slide()

func handle_movement():
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		current_direction = direction.normalized()
		last_direction = current_direction
		character_sprite_component.set_direction(last_direction)

		var current_speed = speed * speed_multiplier
		# Removed the is_hit speed reduction, allowing movement when hit

		velocity = current_direction * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * deceleration_factor * get_physics_process_delta_time())

func update_animation_state():
	if is_hit:
		character_sprite_component.play_hit()
	elif velocity.length() > 10:
		character_sprite_component.play_walk()
	else:
		character_sprite_component.play_idle()

func _input(event):
	if is_dying:
		return
	
	if Input.is_action_just_pressed("attack"):
		print("attack")
		$BasicAttackSkill1.initialize(self)
		$BasicAttackSkill1.execute(last_direction)

func take_damage():
	if is_dying:
		return
	
	is_hit = true
	character_sprite_component.play_hit()
	emit_signal("took_damage")

func _on_flash_timeout():
	# Toggle visibility for flashing effect
	character_sprite_component.modulate.a = 1.0 if character_sprite_component.modulate.a < 1.0 else 0.5

func die():
	is_dying = true
	character_sprite_component.play_death()

func on_hit_animation_finished():
	is_hit = false
	update_animation_state()

func on_death_animation_finished():
	queue_free()
