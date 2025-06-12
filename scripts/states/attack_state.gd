class_name AttackState
extends State

@export var attack_range_area_path: NodePath
@export var wind_up_duration: float = 1.0

var attack_range_area: Area2D
var target_in_range: bool = true
var wind_up_timer: Timer
var is_winding_up: bool = false
var is_red_tinted: bool = false
var wind_up_elapsed: float = 0.0
var next_blink_time: float = 0.0

var original_collision_layer: int
var original_collision_mask: int

func _ready() -> void:
	enemy = get_parent().get_parent()
	
	if attack_range_area_path:
		attack_range_area = get_node(attack_range_area_path)
		attack_range_area.body_exited.connect(_on_attack_range_area_body_exited)
	
	wind_up_timer = Timer.new()
	wind_up_timer.one_shot = true
	wind_up_timer.timeout.connect(_on_wind_up_timeout)
	add_child(wind_up_timer)

func enter(msg: Dictionary = {}) -> void:
	enemy.character_sprite.play_idle()
	is_winding_up = false
	is_red_tinted = false
	wind_up_elapsed = 0.0
	next_blink_time = 0.0
	
	original_collision_layer = enemy.collision_layer
	original_collision_mask = enemy.collision_mask
	
	if enemy.target and attack_range_area:
		target_in_range = attack_range_area.overlaps_body(enemy.target)
	else:
		target_in_range = false
	
	if enemy.skill and !enemy.skill.skill_finished.is_connected(_on_skill_finished):
		enemy.skill.skill_finished.connect(_on_skill_finished)
	if enemy.skill and !enemy.skill.skill_interrupted.is_connected(_on_skill_interrupted):
		enemy.skill.skill_interrupted.connect(_on_skill_interrupted)

func exit() -> void:
	_stop_wind_up()
	_make_movable()
	enemy.container.enemy_queue.erase(enemy.id)
	
	if enemy.skill:
		if enemy.skill.skill_finished.is_connected(_on_skill_finished):
			enemy.skill.skill_finished.disconnect(_on_skill_finished)
		if enemy.skill.skill_interrupted.is_connected(_on_skill_interrupted):
			enemy.skill.skill_interrupted.disconnect(_on_skill_interrupted)

func physics_update(delta: float) -> void:
	if !enemy.target:
		transition_requested.emit("ChaseState")
		return
	
	if !target_in_range:
		transition_requested.emit("ChaseState")
		return
	
	if is_winding_up:
		_face_target()
		_update_blinking(delta)
	
	if enemy.id in enemy.container.enemy_queue and !is_winding_up:
		_make_immovable()
		_start_wind_up()

func _start_wind_up() -> void:
	is_winding_up = true
	is_red_tinted = false
	wind_up_elapsed = 0.0
	next_blink_time = _calculate_next_blink_interval(0.0)
	wind_up_timer.start(wind_up_duration)

func _stop_wind_up() -> void:
	is_winding_up = false
	wind_up_timer.stop()
	_enable_red_tint(false)
	is_red_tinted = false

func _update_blinking(delta: float) -> void:
	wind_up_elapsed += delta
	
	if wind_up_elapsed >= next_blink_time:
		is_red_tinted = !is_red_tinted
		_enable_red_tint(is_red_tinted)
		next_blink_time = wind_up_elapsed + _calculate_next_blink_interval(wind_up_elapsed)

func _calculate_next_blink_interval(elapsed: float) -> float:
	var progress = elapsed / wind_up_duration
	progress = clamp(progress, 0.0, 1.0)
	
	var start_interval = wind_up_duration * 0.4
	var end_interval = wind_up_duration * 0.03
	
	var eased_progress = progress * progress
	return lerp(start_interval, end_interval, eased_progress)

func _make_immovable() -> void:
	enemy.velocity = Vector2.ZERO
	
	if enemy.has_method("get_node") and enemy.get_node_or_null("NavigationAgent"):
		var nav_agent: NavigationAgent2D = enemy.get_node("NavigationAgent")
		nav_agent.set_velocity(Vector2.ZERO)
		nav_agent.avoidance_enabled = false
		nav_agent.set_target_position(enemy.global_position)
	
	enemy.collision_layer = 0
	enemy.collision_mask = 0

func _make_movable() -> void:
	enemy.collision_layer = original_collision_layer
	enemy.collision_mask = original_collision_mask
	
	if enemy.has_method("get_node") and enemy.get_node_or_null("NavigationAgent"):
		var nav_agent: NavigationAgent2D = enemy.get_node("NavigationAgent")
		nav_agent.avoidance_enabled = true

func _attack() -> void:
	if !enemy.target:
		return
	
	_stop_wind_up()
	_face_target()
	var direction = (enemy.target.global_position - enemy.global_position).normalized()
	
	if enemy.skill:
		enemy.skill.execute(direction)

func _face_target() -> void:
	if enemy.target:
		var direction = (enemy.target.global_position - enemy.global_position).normalized()
		enemy.character_sprite.current_direction = direction
		enemy.character_sprite.get_direction()

func _enable_red_tint(enable: bool) -> void:
	enemy.character_sprite.animated_sprite.material.set_shader_parameter("enable_red_tint", enable)

func _on_wind_up_timeout() -> void:
	_attack()

func _on_attack_range_area_body_exited(body: Node2D) -> void:
	if body == enemy.target:
		target_in_range = false
		if is_winding_up:
			_stop_wind_up()

func _on_skill_finished() -> void:
	enemy.container.enemy_queue.erase(enemy.id)
	transition_requested.emit("ChaseState")

func _on_skill_interrupted() -> void:
	enemy.container.enemy_queue.erase(enemy.id)
	print('dss')
	transition_requested.emit("ChaseState")
