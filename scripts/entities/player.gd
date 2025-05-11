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
var current_ba = -1
var current_dash = 0

@onready var character_sprite_component: CharacterSpriteComponent = $CharacterSpriteComponent
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

func _process(delta: float) -> void:
	var attack_index = -1  # Default to -1 (no attack)
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		if ba_timer.is_stopped():
			ba_timer.start(1.2)
		if current_ba == 4:
			ba_timer.start(1.2)
			current_ba = -1
		if ba_timer.time_left > 0:
			current_ba += 1
			attack_index = current_ba  # Set the attack index to the current BA value
	
	var can_dash
	if Input.is_action_just_pressed("dash"):
		dash_timer.start(0.3)
		if dash_timer.time_left > 0:
			current_dash += 1
		if current_dash >= 3:
			can_dash = false
		else:
			can_dash = true
			
	var action_pressed = {
		"skill_1": Input.is_action_just_pressed("skill_1"),
		"skill_2": Input.is_action_just_pressed("skill_2"),
		"attack": attack_index,  # Pass the attack index or -1 if no attack
		"dash": Input.is_action_just_pressed("dash")
	}
	
	skill_manager.process_input(last_direction, action_pressed)
	
func _on_skill_executed(skill: BaseSkill) -> void:
	pass

func _on_skill_ready(skill: BaseSkill) -> void:
	pass
	
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

func _on_ba_timer_timeout() -> void:
	current_ba = -1

func _on_dash_timer_timeout() -> void:
	current_dash = 0
