class_name ChaseState
extends State

# Movement parameters
@export var speed: float = 150.0
@export var path_smoothing: float = 0.25  # 0=sharp turns, 1=very smooth

# Pathfinding parameters
@export var min_update_interval: float = 0.1
@export var max_update_interval: float = 0.5
@export var path_max_distance: float = 10.0
@export var target_desired_distance: float = 5.0

# Stuck recovery
@export var stuck_threshold: float = 1.0
@export var unstuck_force: float = 200.0

# Circling behavior parameters
@export var circling_radius: float = 6.0
@export var circling_speed: float = 3.0
@export var circling_randomization: float = 0.2

# Attack area reference (set this in inspector)
@export var attack_area: Area2D
@export var soft_collision_component: SoftCollisionComponent

# Private variables
var _path_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_position: Vector2
var _current_direction: Vector2 = Vector2.ZERO
var _target_in_attack_range: bool = false
var _current_path = []  # For debug drawing
var _circling: bool = false
var _circling_angle: float = 0.0
var _circling_direction: int = 1  # 1 for clockwise, -1 for counter-clockwise

func enter(msg: Dictionary = {}):
	enemy.character_sprite.play_walk()
	_path_timer = 0.0
	_stuck_timer = 0.0
	_last_position = enemy.global_position
	_target_in_attack_range = false
	_current_path = []
	_circling = false
	
	# Randomize circling direction and starting angle
	_circling_direction = 1 if randf() > 0.5 else -1
	_circling_angle = randf() * TAU
	
	if enemy.navigation_agent:
		enemy.navigation_agent.path_max_distance = path_max_distance
		enemy.navigation_agent.target_desired_distance = target_desired_distance
		enemy.navigation_agent.avoidance_enabled = true
	
	# Connect to attack area signals if not already connected
	if attack_area and !attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

func physics_update(delta: float):
	if !enemy.target or !enemy.navigation_agent:
		return
	
	# Check if we should be in circling mode or chasing mode
	_update_circling_status()
	
	if _circling:
		_perform_circling_behavior(delta)
	else:
		_perform_chase_behavior(delta)
	
	# Stuck detection and recovery
	_handle_stuck_situation(delta)
	
	# Attack transition check
	if _target_in_attack_range:
		if enemy.id not in enemy.container.enemy_queue:
			if enemy.container.enemy_queue.size() < 5:
				enemy.container.enemy_queue.push_back(enemy.id)
				transition_requested.emit("AttackState")
				await get_tree().create_timer(3).timeout
				enemy.container.enemy_queue.erase(enemy.id)
				
func exit():
	enemy.velocity = Vector2.ZERO

func _on_attack_area_body_entered(body: Node2D):
	if body == enemy.target:
		_target_in_attack_range = true

func _on_attack_area_body_exited(body: Node2D):
	if body == enemy.target:
		_target_in_attack_range = false

func _update_circling_status():
	if _target_in_attack_range and enemy.id not in enemy.container.enemy_queue:
		_circling = true
	else:
		_circling = false

func _perform_chase_behavior(delta: float):
	# Dynamic path update rate based on distance
	var distance_to_target = enemy.global_position.distance_to(enemy.target.global_position)
	_path_timer -= delta * lerp(1.5, 0.5, distance_to_target / 500.0)
	
	# Update path periodically
	if _path_timer <= 0.0:
		enemy.navigation_agent.target_position = _get_predictive_target_position()
		_path_timer = lerp(min_update_interval, max_update_interval, distance_to_target / 500.0)
		
		# Store path for debug drawing
		_current_path = enemy.navigation_agent.get_current_navigation_path()
	
	# Get movement direction
	var next_pos = enemy.navigation_agent.get_next_path_position()
	if next_pos != Vector2.INF:
		var raw_direction = (next_pos - enemy.global_position).normalized()
		
		# Apply steering behaviors
		if soft_collision_component and soft_collision_component.enabled:
			var avoidance = soft_collision_component.get_avoidance_force()
			if avoidance != Vector2.ZERO:
				raw_direction += avoidance
				raw_direction = raw_direction.normalized()
		
		# Smooth direction changes
		_current_direction = _current_direction.slerp(raw_direction, 1.0 - path_smoothing)
		enemy.velocity = _current_direction * speed

func _perform_circling_behavior(delta: float):
	if !enemy.target:
		return
		
	# Update the circling angle
	_circling_angle += circling_speed * delta * _circling_direction
	
	# Add some randomization to make movement more natural
	var radius = circling_radius * (1.0 + sin(_circling_angle * 3.0) * circling_randomization)
	
	# Calculate the desired position on the circle around the target
	var circle_position = enemy.target.global_position + Vector2(
		cos(_circling_angle) * radius,
		sin(_circling_angle) * radius
	)
	
	# Set the direction toward the circling position
	var raw_direction = (circle_position - enemy.global_position).normalized()
	
	# Apply soft collision avoidance if needed
	if soft_collision_component and soft_collision_component.enabled:
		var avoidance = soft_collision_component.get_avoidance_force()
		if avoidance != Vector2.ZERO:
			raw_direction += avoidance
			raw_direction = raw_direction.normalized()
	
	# Smooth direction changes
	_current_direction = _current_direction.slerp(raw_direction, 1.0 - path_smoothing)
	
	# Calculate speed based on how close we are to the desired circle position
	var distance_to_circle_pos = enemy.global_position.distance_to(circle_position)
	var adjusted_speed = speed * clamp(distance_to_circle_pos / (radius * 0.5), 0.5, 1.2)
	
	enemy.velocity = _current_direction * adjusted_speed
	
	# Occasionally change direction for more interesting movement
	if randf() < 0.005:  # 0.5% chance per frame to switch direction
		_circling_direction = -_circling_direction

func _get_predictive_target_position() -> Vector2:
	var base_target = enemy.target.global_position
	
	# Predict player movement if they're moving fast
	if enemy.target.velocity.length() > 50:
		var lead_time = clamp(enemy.global_position.distance_to(base_target) / speed, 0.1, 0.5)
		return base_target + (enemy.target.velocity * lead_time)
	
	return base_target

func _handle_stuck_situation(delta: float):
	# Check if we're moving
	if enemy.global_position.distance_to(_last_position) < 5.0:
		_stuck_timer += delta
		if _stuck_timer >= stuck_threshold:
			_recover_from_stuck()
	else:
		_stuck_timer = 0.0
	_last_position = enemy.global_position

func _recover_from_stuck():
	# Random push direction with slight upward bias
	var random_angle = randf_range(-PI/4, PI/4)
	var push_dir = Vector2.UP.rotated(random_angle)
	enemy.velocity += push_dir * unstuck_force
	_stuck_timer = -1.0  # Prevent immediate re-triggering
	
	# If we're circling, also change direction to help get unstuck
	if _circling:
		_circling_direction = -_circling_direction
