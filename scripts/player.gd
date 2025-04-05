extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var deceleration_factor: float = 7
@export var attack_speed_multiplier: float = 0
@export var attack_duration: float = 0.3
@export var attack_cooldown: float = 0.5
@export var attack_hitbox_duration: float = 0.2

@export var attack_hitbox_offset_right: float = 30.0
@export var attack_hitbox_offset_left: float = 30.0
@export var attack_hitbox_offset_up: float = 30.0
@export var attack_hitbox_offset_down: float = 30.0

# Invulnerability parameters
@export var invulnerable_duration: float = 1.5
@export var invulnerable_flash_speed: float = 0.1

var last_direction: Vector2 = Vector2(0, 1)
var current_direction: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var is_hit: bool = false
var is_dying: bool = false
var can_attack: bool = true
var attack_hitbox_active: bool = false
var is_invulnerable: bool = false

@onready var character_sprite_component = $CharacterSpriteComponent
@onready var attack_timer = $AttackTimer
@onready var cooldown_timer = $CooldownTimer
@onready var hitbox_timer = $HitboxTimer
@onready var attack_hitbox = $AttackComponent
@onready var invulnerability_timer = $InvulnerabilityTimer
@onready var flash_timer = $FlashTimer

signal took_damage
signal attacked

func _ready():
	attack_timer.one_shot = true
	cooldown_timer.one_shot = true
	hitbox_timer.one_shot = true
	
	# Create timers if they don't exist
	if not has_node("InvulnerabilityTimer"):
		invulnerability_timer = Timer.new()
		invulnerability_timer.name = "InvulnerabilityTimer"
		invulnerability_timer.one_shot = true
		add_child(invulnerability_timer)
	
	if not has_node("FlashTimer"):
		flash_timer = Timer.new()
		flash_timer.name = "FlashTimer"
		flash_timer.one_shot = false
		add_child(flash_timer)

	attack_timer.timeout.connect(_on_attack_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	hitbox_timer.timeout.connect(_on_hitbox_timer_for_cleanup)
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	flash_timer.timeout.connect(_on_flash_timeout)

	character_sprite_component.set_direction(last_direction)
	character_sprite_component.play_idle()

	# Disable attack component at the start
	attack_hitbox.visible = false
	attack_hitbox.monitoring = false
	
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

		var current_speed = speed
		if is_attacking:
			current_speed *= attack_speed_multiplier
		# Removed the is_hit speed reduction, allowing movement when hit

		velocity = current_direction * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * deceleration_factor * get_physics_process_delta_time())

func update_animation_state():
	if is_attacking:
		character_sprite_component.play_attack()
	elif is_hit:
		character_sprite_component.play_hit()
	elif velocity.length() > 10:
		character_sprite_component.play_walk()
	else:
		character_sprite_component.play_idle()

func _input(event):
	if is_dying:
		return

	if event.is_action_pressed("attack") and can_attack:
		emit_signal("attacked")
		start_attack()

func start_attack():
	is_attacking = true
	can_attack = false
	attack_hitbox_active = true

	character_sprite_component.play_attack()
	spawn_attack_hitbox()

	attack_timer.start(attack_duration)
	cooldown_timer.start(attack_cooldown)
	hitbox_timer.start(attack_hitbox_duration)

func get_offset_for_direction(direction: Vector2) -> float:
	if abs(direction.x) > abs(direction.y):
		return attack_hitbox_offset_right if direction.x > 0 else attack_hitbox_offset_left
	else:
		return attack_hitbox_offset_down if direction.y > 0 else attack_hitbox_offset_up

func spawn_attack_hitbox():
	var offset_value = get_offset_for_direction(last_direction)
	var hitbox_position = last_direction * offset_value
	attack_hitbox.position = hitbox_position

	attack_hitbox.set_direction(last_direction)

	attack_hitbox.visible = true
	attack_hitbox.monitoring = true

func _on_hitbox_timer_for_cleanup():
	attack_hitbox.visible = false
	attack_hitbox.monitoring = false

func _on_enemy_hit(enemy):
	if enemy.has_method("take_damage"):
		enemy.take_damage()
		
func _on_attack_timeout():
	is_attacking = false

func _on_cooldown_timeout():
	can_attack = true

func _on_hitbox_timeout():
	attack_hitbox_active = false

func take_damage():
	if is_dying or is_invulnerable:
		return
	
	is_hit = true
	character_sprite_component.play_hit()
	emit_signal("took_damage")
	
	# Start invulnerability
	start_invulnerability()

func start_invulnerability():
	is_invulnerable = true
	invulnerability_timer.start(invulnerable_duration)
	flash_timer.start(invulnerable_flash_speed)

func _on_invulnerability_timeout():
	is_invulnerable = false
	flash_timer.stop()
	character_sprite_component.modulate.a = 1.0  # Ensure visibility is restored

func _on_flash_timeout():
	# Toggle visibility for flashing effect
	character_sprite_component.modulate.a = 1.0 if character_sprite_component.modulate.a < 1.0 else 0.5

func die():
	is_dying = true
	character_sprite_component.play_death()

func on_attack_animation_finished():
	if is_attacking:
		character_sprite_component.play_attack()

func on_hit_animation_finished():
	is_hit = false
	update_animation_state()

func on_death_animation_finished():
	queue_free()
