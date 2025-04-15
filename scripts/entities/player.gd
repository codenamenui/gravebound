extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var deceleration_factor: float = 7.0
@export var hit_timer_duration: float = 0.2

var last_direction: Vector2 = Vector2(0, 1)
var current_direction: Vector2 = Vector2.ZERO
var is_hit: bool = false
var is_attacking: bool = false
var is_dying: bool = false
var speed_multiplier: float = 1.0
var current_skill = null

@onready var character_sprite_component: CharacterSpriteComponent = $CharacterSpriteComponent
@onready var hit_timer: Timer = $Timers/HitTimer

signal took_damage
signal attacked

func _ready():
	character_sprite_component.set_direction(last_direction)
	character_sprite_component.play_idle()
	hit_timer.wait_time = hit_timer_duration
	
	for child in get_children():
		if child is BaseSkill:
			child.initialize(self)

func _physics_process(delta):
	if is_dying:
		return
	
	if is_attacking and current_skill and current_skill.movement_control_mode == 0:
		pass
	else:
		handle_movement()
	
	if not is_hit and not is_attacking:
		character_sprite_component.update_animation_based_on_state()
	
	move_and_slide()

func handle_movement(direction: Vector2 = Vector2()):
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if is_attacking and current_skill and current_skill.movement_control_mode == 1:
		if direction != Vector2.ZERO and current_skill.can_change_direction_during_skill:
			current_direction = direction.normalized()
			last_direction = current_direction
			character_sprite_component.set_direction(last_direction)
		return
	
	if direction != Vector2.ZERO:
		current_direction = direction.normalized()
		last_direction = current_direction
		character_sprite_component.set_direction(last_direction)
		var current_speed = speed * speed_multiplier
		velocity = current_direction * current_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * deceleration_factor * get_physics_process_delta_time())

func _input(event):
	if is_dying or is_hit or is_attacking:
		return
	
	if Input.is_action_just_pressed("attack"):
		var skill = $BasicAttackSkill1
		if skill.execute(last_direction):
			current_skill = skill
			emit_signal("attacked")
	if Input.is_action_just_pressed("dash"):
			var skill = $DashSkill
			if skill.execute(last_direction):
				current_skill = skill

func apply_impulse(impulse: Vector2):
	velocity = impulse

func set_last_direction(direction: Vector2):
	last_direction = direction
	character_sprite_component.set_direction(last_direction)

func take_damage():
	if is_dying:
		return
	
	emit_signal("took_damage")
	is_hit = true
	hit_timer.start()
	
	if not hit_timer.timeout.is_connected(_on_hit_timer_timeout):
		hit_timer.timeout.connect(_on_hit_timer_timeout)
	
	if is_attacking:
		return
	
	character_sprite_component.play_hit()

func _on_hit_timer_timeout():
	is_hit = false

func die():
	is_dying = true
	character_sprite_component.play_death()
