extends CharacterBody2D
class_name Player

@export var speed: float = 200.0
@export var deceleration_factor: float = 7.0
@export var hit_timer_duration: float = 0.2
@export var ba_time: float = 1.5

var base_speed: float
var base_deceleration_factor: float
var base_hit_timer_duration: float
var base_ba_time: float
var initial_position: Vector2

var last_direction: Vector2 = Vector2(0, 1)
var current_direction: Vector2 = Vector2.ZERO
var is_hit: bool = false
var is_attacking: bool = false
var is_dying: bool = false
var speed_multiplier: float = 1.0  # For skill effects - don't change this
var current_skill = null
var current_ba = -1
var current_dash = 0

# Existing additive bonuses
var additional_damage: float = 0.0
var speed_bonus: float = 0.0
var health_bonus: int = 0
var max_health_bonus: int = 0

# New multiplicative and bonus stats
var damage_multiplier: float = 1.0
var movement_speed_multiplier: float = 1.0  # New multiplier for movement speed bonuses
var health_multiplier: float = 1.0
var damage_reduction: float = 0.0  # Flat damage reduction
var damage_resistance: float = 1.0  # Multiplicative damage reduction (1.0 = no resistance, 0.8 = 20% less damage)
var lifesteal_percent: float = 0.0  # 0.0 to 1.0 (0% to 100%)
var max_dash_bonus: int = 0  # Additional dashes beyond base 3

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
	initial_position = global_position
	_store_base_stats()
	
	skill_manager.initialize(self)
	
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
	
	if not ba_timer.timeout.is_connected(_on_ba_timer_timeout):
		ba_timer.timeout.connect(_on_ba_timer_timeout)
	if not dash_timer.timeout.is_connected(_on_dash_timer_timeout):
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	if not health_component.health_depleted.is_connected(_on_health_component_health_depleted):
		health_component.health_depleted.connect(_on_health_component_health_depleted)
	
	for child in get_children():
		if child is BaseSkill:
			child.initialize(self)
	
	_update_animation()

func _store_base_stats():
	base_speed = speed
	base_deceleration_factor = deceleration_factor
	base_hit_timer_duration = hit_timer_duration
	base_ba_time = ba_time

func _physics_process(delta):
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
		
	var attack_index = -1
	
	if Input.is_action_just_pressed("attack") and not is_attacking:
		if ba_timer.is_stopped():
			ba_timer.start(ba_time)
		if current_ba == 4:
			ba_timer.start(1.2)
			current_ba = -1
		if ba_timer.time_left > 0:
			current_ba += 1
			attack_index = current_ba
	
	# Fixed dash implementation - limit to 3 + bonus dashes
	var max_dashes = 3 + max_dash_bonus
	var can_dash = true
	if Input.is_action_just_pressed("dash"):
		if dash_timer.is_stopped():
			dash_timer.start(1)
			current_dash = 0
		if dash_timer.time_left > 0:
			current_dash += 1
		if current_dash > max_dashes:
			can_dash = false
			current_dash = max_dashes  # Cap at maximum
			
	var action_pressed = {
		"skill_1": Input.is_action_just_pressed("skill_1"),
		"skill_2": Input.is_action_just_pressed("skill_2"),
		"attack": attack_index,
		"dash": Input.is_action_just_pressed("dash") and can_dash
	}
	
	skill_manager.process_input(last_direction, action_pressed)

func _update_animation():
	if is_dying:
		character_sprite_component.play_death()
		return
	
	if is_hit:
		character_sprite_component.play_hit()
		return
	
	if is_attacking:
		return
	
	if velocity.length() > 10.0:
		character_sprite_component.play_walk()
		pass
	else:
		character_sprite_component.play_idle()
		
func _on_skill_executed(skill: BaseSkill) -> void:
	is_attacking = true
	current_skill = skill
	
	if skill.has_signal("skill_finished") and not skill.skill_finished.is_connected(_on_skill_finished):
		skill.skill_finished.connect(_on_skill_finished)

func _on_skill_ready(skill: BaseSkill) -> void:
	pass

func _on_skill_finished():
	is_attacking = false
	current_skill = null
	
func handle_movement(direction: Vector2 = Vector2()):
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

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
		# Apply both additive and multiplicative speed bonuses
		var current_speed = ((speed + speed_bonus) * movement_speed_multiplier) * speed_multiplier
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
	
	# Apply damage reduction and resistance
	var final_damage = max(1, (damage - damage_reduction) * damage_resistance)
	
	var is_invincible = health_component.take_damage(int(final_damage))
	
	if is_invincible:
		return
	
	emit_signal("took_damage")
	
	if hit_timer.timeout.is_connected(_on_hit_timer_timeout):
		hit_timer.timeout.disconnect(_on_hit_timer_timeout)
	
	is_hit = true
	hit_timer.wait_time = hit_timer_duration
	hit_timer.start()
	
	hit_timer.timeout.connect(_on_hit_timer_timeout)
	
	character_sprite_component.play_hit()

func deal_damage_to_enemy(base_damage: float) -> float:
	var total_damage = (base_damage + additional_damage) * damage_multiplier
	
	# Apply lifesteal if we have any
	if lifesteal_percent > 0.0:
		var heal_amount = total_damage * lifesteal_percent
		if health_component.has_method("heal"):
			health_component.heal(int(heal_amount))
	
	return total_damage

func _on_hit_timer_timeout():
	is_hit = false

func _on_ba_timer_timeout() -> void:
	current_ba = -1

func _on_dash_timer_timeout() -> void:
	current_dash = 0

func _on_health_component_health_depleted() -> void:
	is_dying = true
	$death.show()
	character_sprite_component.play_death()

# Existing additive bonus functions
func add_damage_bonus(bonus: float):
	additional_damage += bonus

func add_speed_bonus(bonus: float):
	speed_bonus += bonus

func add_health_bonus(bonus: int):
	health_bonus += bonus
	if health_component.has_method("add_current_health"):
		health_component.add_current_health(bonus)

func add_max_health_bonus(bonus: int):
	max_health_bonus += bonus
	if health_component.has_method("add_max_health"):
		health_component.add_max_health(bonus)

# New multiplicative and special bonus functions
func add_damage_multiplier(multiplier: float):
	damage_multiplier *= multiplier

func add_movement_speed_multiplier(multiplier: float):
	movement_speed_multiplier *= multiplier

func add_health_multiplier(multiplier: float):
	health_multiplier *= multiplier
	# Apply to current and max health if methods exist
	if health_component.has_method("multiply_health"):
		health_component.multiply_health(multiplier)

func add_damage_reduction(reduction: float):
	damage_reduction += reduction

func add_damage_resistance(resistance_multiplier: float):
	# Stack resistance multiplicatively (0.8 * 0.9 = 0.72 = 28% total reduction)
	damage_resistance *= resistance_multiplier

func add_lifesteal(percent: float):
	lifesteal_percent += percent
	lifesteal_percent = clamp(lifesteal_percent, 0.0, 1.0)  # Cap at 100%

func add_dash_count_bonus(bonus: int):
	max_dash_bonus += bonus

# Getter functions for total stats
func get_total_damage() -> float:
	return (additional_damage) * damage_multiplier

func get_total_speed() -> float:
	return (speed + speed_bonus) * movement_speed_multiplier

func get_max_dashes() -> int:
	return 3 + max_dash_bonus

func reset_player():
	global_position = initial_position
	
	speed = base_speed
	deceleration_factor = base_deceleration_factor
	hit_timer_duration = base_hit_timer_duration
	ba_time = base_ba_time
	
	# Reset additive bonuses
	additional_damage = 0.0
	speed_bonus = 0.0
	health_bonus = 0
	max_health_bonus = 0
	
	# Reset multiplicative bonuses
	damage_multiplier = 1.0
	movement_speed_multiplier = 1.0
	health_multiplier = 1.0
	damage_reduction = 0.0
	damage_resistance = 1.0
	lifesteal_percent = 0.0
	max_dash_bonus = 0
	
	last_direction = Vector2(0, 1)
	current_direction = Vector2.ZERO
	is_hit = false
	is_attacking = false
	is_dying = false
	speed_multiplier = 1.0
	current_skill = null
	current_ba = -1
	current_dash = 0
	
	velocity = Vector2.ZERO
	
	if health_component.has_method("reset_health"):
		health_component.reset_health()
	
	character_sprite_component.set_direction(last_direction)
	
	if $death.visible:
		$death.hide()
	
	_update_animation()
