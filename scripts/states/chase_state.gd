class_name ChaseState
extends State

# Movement parameters
@export var speed: float = 150.0
@export var attack_range: float = 50.0
@export var path_smoothing: float = 0.25  # 0=sharp turns, 1=very smooth

# Pathfinding parameters
@export var min_update_interval: float = 0.1
@export var max_update_interval: float = 0.5
@export var path_max_distance: float = 10.0
@export var target_desired_distance: float = 5.0

# Crowd avoidance
@export var avoidance_strength: float = 2.5
@export var detection_radius: float = 40.0

# Stuck recovery
@export var stuck_threshold: float = 1.0
@export var unstuck_force: float = 200.0

# Private variables
var _path_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_position: Vector2
var _current_direction: Vector2 = Vector2.ZERO

func enter():
	_path_timer = 0.0
	_stuck_timer = 0.0
	_last_position = enemy.global_position
	
	if enemy.navigation_agent:
		enemy.navigation_agent.path_max_distance = path_max_distance
		enemy.navigation_agent.target_desired_distance = target_desired_distance
		enemy.navigation_agent.avoidance_enabled = true
		enemy.navigation_agent.radius = detection_radius * 0.5

func physics_update(delta: float):
	if !enemy.target or !enemy.navigation_agent:
		return
	
	# Dynamic path update rate based on distance
	var distance_to_target = enemy.global_position.distance_to(enemy.target.global_position)
	_path_timer -= delta * lerp(1.5, 0.5, distance_to_target / 500.0)
	
	# Update path periodically
	if _path_timer <= 0.0:
		enemy.navigation_agent.target_position = _get_predictive_target_position()
		_path_timer = lerp(min_update_interval, max_update_interval, distance_to_target / 500.0)
	
	# Get movement direction
	var next_pos = enemy.navigation_agent.get_next_path_position()
	if next_pos != Vector2.INF:
		var raw_direction = (next_pos - enemy.global_position).normalized()
		
		# Apply crowd avoidance
		if avoidance_strength > 0:
			raw_direction += _get_avoidance_force() * avoidance_strength
			raw_direction = raw_direction.normalized()
		
		# Smooth direction changes
		_current_direction = _current_direction.slerp(raw_direction, 1.0 - path_smoothing)
		enemy.velocity = _current_direction * speed
	
	# Stuck detection and recovery
	_handle_stuck_situation(delta)
	
	# Attack transition check
	if distance_to_target <= attack_range:
		transition_requested.emit("AttackState")

func exit():
	enemy.velocity = Vector2.ZERO

func _get_predictive_target_position() -> Vector2:
	var base_target = enemy.target.global_position
	
	# Predict player movement if they're moving fast
	if enemy.target.velocity.length() > 50:
		var lead_time = clamp(enemy.global_position.distance_to(base_target) / speed, 0.1, 0.5)
		return base_target + (enemy.target.velocity * lead_time)
	
	return base_target

func _get_avoidance_force() -> Vector2:
	var avoidance_force = Vector2.ZERO
	var space = enemy.get_world_2d().direct_space_state
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.collision_mask = enemy.collision_mask
	query.shape = CircleShape2D.new()
	query.shape.radius = detection_radius
	query.transform = Transform2D(0, enemy.global_position)
	
	for result in space.intersect_shape(query):
		if result.collider != enemy:
			var away_vec = (enemy.global_position - result.collider.global_position).normalized()
			var weight = 1.0 - (enemy.global_position.distance_to(result.collider.global_position) / detection_radius)
			avoidance_force += away_vec * weight
	
	return avoidance_force

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
