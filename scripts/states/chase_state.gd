class_name ChaseState
extends State

@export var speed: float = 150.0
@export var attack_range: float = 50.0
@export var path_update_interval: float = 0.3

var _path_timer: float = 0.0

func enter():
	_path_timer = 0.0
	if enemy.navigation_agent:
		enemy.navigation_agent.path_max_distance = 10.0
		enemy.navigation_agent.target_desired_distance = 5.0

func physics_update(delta: float):
	if !enemy.target or !enemy.navigation_agent:
		return
	
	# Update path periodically
	_path_timer -= delta
	if _path_timer <= 0.0:
		enemy.navigation_agent.target_position = enemy.target.global_position
		_path_timer = path_update_interval
	
	# Get next path position with safety check
	var next_pos = enemy.navigation_agent.get_next_path_position()
	if next_pos != Vector2.INF:
		var direction = (next_pos - enemy.global_position).normalized()
		enemy.velocity = direction * speed
	#print(enemy.velocity)
	# Attack transition
	if enemy.global_position.distance_to(enemy.target.global_position) <= attack_range:
		transition_requested.emit("AttackState")

func exit():
	enemy.velocity = Vector2.ZERO
