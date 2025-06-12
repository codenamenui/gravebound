extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var deceleration_factor: float = 7.0
@export var hit_timer_duration: float = 0.2
@export var ba_time: float = 1.5

var last_direction: Vector2 = Vector2(0, 1)
var current_direction: Vector2 = Vector2.ZERO
var is_hit: bool = false
var is_attacking: bool = false
var is_dying: bool = false
var speed_multiplier: float = 1.0
var current_skill = null
var current_ba = -1
var current_dash = 0

@onready var character_sprite_component: CharacterSpriteComponent = $CharacterSpriteComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hit_timer: Timer = $Timers/HitTimer
@onready var ba_timer: Timer = $Timers/BATimer
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var skill_manager: SkillManagerComponent = $SkillManagerComponent
@onready var skills: Node = $Skills

signal took_damage
signal attacked

func _ready():
	# Initialize the skill manager with this character
	skill_manager.initialize(self)
	
	# Connect to signals if needed
	skill_manager.skill_executed.connect(_on_skill_executed)
	skill_manager.skill_ready.connect(_on_skill_ready)
	
	for skill in skills.get_children():
		skill.camera = get_parent().get_node_or_null("Camera2D")
		if skill.name.begins_with("BA"):
			skill_manager.add_skill(skill, 0)
		elif skill.name.begins_with("Dash"):
			skill_manager.add_skill(skill, 1)
		else:
			skill_manager.add_skill(skill, 3)
	
	character_sprite_component.set_direction(last_direction)
	hit_timer.wait_time = hit_timer_duration
	
	# Connect timers
	if not ba_timer.timeout.is_connected(_on_ba_timer_timeout):
		ba_timer.timeout.connect(_on_ba_timer_timeout)
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not health_component.health_depleted.is_connected(_on_health_component_health_depleted):
		health_component.health_depleted.connect(_on_health_component_health_depleted)
	
	for child in get_children():
		if child is BaseSkill:
			child.initialize(self)
	
	# Play initial animation
	_update_animation()

func _physics_process(delta):
	# Always update animation first, regardless of state
	_update_animation()
	
	if is_dying:
		return
	
	if is_attacking and current_skill and current_skill.movement_control_mode == 0:
		pass
	else:
		handle_movement()
	
	move_and_slide()

func _process(delta: float) -> void:
	if is_dying:
		return
		
	var attack_index = -1  # Default to -1 (no attack)
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		if ba_timer.is_stopped():
			ba_timer.start(ba_time)
		if current_ba == 4:
			ba_timer.start(1.2)
			current_ba = -1
		if ba_timer.time_left > 0:
			current_ba += 1
			attack_index = current_ba  # Set the attack index to the current BA value
	
	var can_dash = true
	if Input.is_action_just_pressed("dash"):
		if dash_timer.is_stopped():
			dash_timer.start(0.3)
			current_dash = 0
		if dash_timer.time_left > 0:
			current_dash += 1
		if current_dash >= 3:
			can_dash = false
			
	var action_pressed = {
		"skill_1": Input.is_action_just_pressed("skill_1"),
		"skill_2": Input.is_action_just_pressed("skill_2"),
		"attack": attack_index,  # Pass the attack index or -1 if no attack
		"dash": Input.is_action_just_pressed("dash") and can_dash
	}
	
	skill_manager.process_input(last_direction, action_pressed)

func _update_animation():
	# Priority-based animation system
	if is_dying:
		character_sprite_component.play_death()
		return
	
	if is_hit:
		character_sprite_component.play_hit()
		return  # Don't process any other animations while hit
	
	if is_attacking:
		# Let the skill handle its own animation
		return
	
	# Only update idle/walk animations if we're not in a special state
	if velocity.length() > 10.0:  # Moving
		character_sprite_component.play_walk()
		pass
	else:  # Idle
		character_sprite_component.play_idle()
		
func _on_skill_executed(skill: BaseSkill) -> void:
	is_attacking = true
	current_skill = skill
	
	# Connect to skill finished signal if available
	if skill.has_signal("skill_finished") and not skill.skill_finished.is_connected(_on_skill_finished):
		skill.skill_finished.connect(_on_skill_finished)

func _on_skill_ready(skill: BaseSkill) -> void:
	pass

func _on_skill_finished():
	is_attacking = false
	current_skill = null
	# Animation will be updated in the next frame via _update_animation()
	
func handle_movement(direction: Vector2 = Vector2()):
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Don't allow any movement or direction changes when dead
	if is_dying:
		velocity = velocity.move_toward(Vector2.ZERO, speed * deceleration_factor * get_physics_process_delta_time())
		return

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

func apply_impulse(impulse: Vector2):
	velocity = impulse

func set_last_direction(direction: Vector2):
	last_direction = direction
	character_sprite_component.set_direction(last_direction)

func take_damage(damage: int):
	if is_dying:
		return
	
	# Check if player is invincible (health_component returns true)
	var is_invincible = health_component.take_damage(damage)
	
	if is_invincible:
		# Player is invincible, just return to normal animation
		return
	
	emit_signal("took_damage")
	
	# Always refresh hit animation - stop current hit timer and restart
	if hit_timer.timeout.is_connected(_on_hit_timer_timeout):
		hit_timer.timeout.disconnect(_on_hit_timer_timeout)
	
	is_hit = true
	hit_timer.wait_time = hit_timer_duration
	hit_timer.start()
	
	# Reconnect the timer
	hit_timer.timeout.connect(_on_hit_timer_timeout)
	
	# Force immediate hit animation
	character_sprite_component.play_hit()

func _on_hit_timer_timeout():
	is_hit = false

func _on_ba_timer_timeout() -> void:
	current_ba = -1

func _on_dash_timer_timeout() -> void:
	current_dash = 0

func _on_health_component_health_depleted() -> void:
	is_dying = true
	$death.show()
	# Force immediate animation update for death
	character_sprite_component.play_death()
