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
var speed_multiplier: float = 1.0
var current_skill = null
var current_ba = -1
var current_dash = 0
var is_walking_sfx_playing: bool = false

var additional_damage: float = 0.0
var speed_bonus: float = 0.0
var health_bonus: int = 0
var max_health_bonus: int = 0

var damage_multiplier: float = 1.0
var movement_speed_multiplier: float = 1.0
var health_multiplier: float = 1.0
var damage_reduction: float = 0.0
var damage_resistance: float = 1.0
var lifesteal_percent: float = 0.0
var max_dash_bonus: int = 0

var footstep_timer: float = 0.0
var footstep_interval: float = 0.25
var was_walking: bool = false

var player_level: int = 1

var stat_growth = {
	"base_damage": 2.0,
	"max_health": 5,
	"movement_speed": 3.0,
	"damage_multiplier": 0.02,
	"speed_multiplier": 0.015,
	"damage_reduction": 0.5
}

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
		if current_ba == 1:
			ba_timer.start(ba_time)
			current_ba = -1
		if ba_timer.time_left > 0:
			current_ba += 1
			attack_index = current_ba
	
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
			current_dash = max_dashes
			
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
		
		if not was_walking:
			play_sfx("player_walk")
			footstep_timer = footstep_interval
			was_walking = true
		else:
			footstep_timer -= get_process_delta_time()
			if footstep_timer <= 0.0:
				play_sfx("player_walk")
				footstep_timer = footstep_interval
	else:
		character_sprite_component.play_idle()
		was_walking = false
		footstep_timer = 0.0
		
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
	
	var final_damage = max(1, (damage - damage_reduction) * damage_resistance)
	
	var is_invincible = health_component.take_damage(int(final_damage))
	
	if is_invincible:
		return
	
	play_sfx("player_hurt")
	
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
	
	if lifesteal_percent > 0.0:
		var heal_amount = total_damage * lifesteal_percent
		if health_component.has_method("heal"):
			health_component.heal(int(heal_amount))
	
	return total_damage

func play_sfx(sound_name: String):
	AudioManager.play_sfx(sound_name)

func _on_hit_timer_timeout():
	is_hit = false

func _on_ba_timer_timeout() -> void:
	current_ba = -1

func _on_dash_timer_timeout() -> void:
	current_dash = 0

func _on_health_component_health_depleted() -> void:
	is_dying = true
	character_sprite_component.play_death()
	SceneManager.transition_to_state(GameData.GameState.GAME_OVER)

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

func add_damage_multiplier(multiplier: float):
	damage_multiplier *= multiplier

func add_movement_speed_multiplier(multiplier: float):
	movement_speed_multiplier *= multiplier

func add_health_multiplier(multiplier: float):
	health_multiplier *= multiplier
	if health_component.has_method("multiply_health"):
		health_component.multiply_health(multiplier)

func add_damage_reduction(reduction: float):
	damage_reduction += reduction

func add_damage_resistance(resistance_multiplier: float):
	damage_resistance *= resistance_multiplier

func add_lifesteal(percent: float):
	lifesteal_percent += percent
	lifesteal_percent = clamp(lifesteal_percent, 0.0, 1.0)

func add_dash_count_bonus(bonus: int):
	max_dash_bonus += bonus

func get_total_damage() -> float:
	return (additional_damage) * damage_multiplier

func get_total_speed() -> float:
	return (speed + speed_bonus) * movement_speed_multiplier

func get_max_dashes() -> int:
	return 3 + max_dash_bonus

func level_up(level_amount: int = 1):
	for i in range(level_amount):
		player_level += 1
		
		_apply_base_level_bonuses()
		
		var num_random_bonuses = randi_range(1, 2)
		for j in range(num_random_bonuses):
			_apply_random_level_bonus()
		
		_play_level_up_effects()
		
		print("Level Up! Now level ", player_level)

func _apply_base_level_bonuses():
	additional_damage += stat_growth.base_damage
	add_max_health_bonus(stat_growth.max_health)
	speed_bonus += stat_growth.movement_speed

func _apply_random_level_bonus():
	var random_bonuses = [
		"damage_mult",
		"speed_mult", 
		"damage_reduction",
		"health_bonus",
		"lifesteal",
		"dash_bonus"
	]
	
	var chosen_bonus = random_bonuses[randi() % random_bonuses.size()]
	
	match chosen_bonus:
		"damage_mult":
			add_damage_multiplier(1.0 + stat_growth.damage_multiplier)
			print("  + Damage multiplier increased!")
			
		"speed_mult":
			add_movement_speed_multiplier(1.0 + stat_growth.speed_multiplier)
			print("  + Movement speed multiplier increased!")
			
		"damage_reduction":
			add_damage_reduction(stat_growth.damage_reduction)
			print("  + Damage reduction improved!")
			
		"health_bonus":
			var health_boost = randi_range(8, 15)
			add_health_bonus(health_boost)
			print("  + Health restored by ", health_boost, "!")
			
		"lifesteal":
			var lifesteal_boost = randf_range(0.01, 0.03)
			add_lifesteal(lifesteal_boost)
			print("  + Lifesteal increased by ", lifesteal_boost * 100, "%!")
			
		"dash_bonus":
			if player_level % 5 == 0:
				add_dash_count_bonus(1)
				print("  + Extra dash charge gained!")

func _play_level_up_effects():
	play_sfx("level_up")
	_create_level_up_particle_effect()

func _create_level_up_particle_effect():
	if has_node("LevelUpEffect"):
		$LevelUpEffect.restart()

func get_current_level() -> int:
	return player_level

func reset_player():
	global_position = initial_position
	
	speed = base_speed
	deceleration_factor = base_deceleration_factor
	hit_timer_duration = base_hit_timer_duration
	ba_time = base_ba_time
	
	additional_damage = 0.0
	speed_bonus = 0.0
	health_bonus = 0
	max_health_bonus = 0
	
	damage_multiplier = 1.0
	movement_speed_multiplier = 1.0
	health_multiplier = 1.0
	damage_reduction = 0.0
	damage_resistance = 1.0
	lifesteal_percent = 0.0
	max_dash_bonus = 0
	
	player_level = 1
	
	last_direction = Vector2(0, 1)
	current_direction = Vector2.ZERO
	is_hit = false
	is_attacking = false
	is_dying = false
	speed_multiplier = 1.0
	current_skill = null
	current_ba = -1
	current_dash = 0
	is_walking_sfx_playing = false
	
	velocity = Vector2.ZERO
	
	if health_component.has_method("reset_health"):
		health_component.reset_health()
	
	character_sprite_component.set_direction(last_direction)
	
	if $death.visible:
		$death.hide()
	
	_update_animation()
