class_name ChaseState
extends State

var target_in_attack_range = false
@export var speed = 300

func enter(msg: Dictionary = {}):
	enemy.character_sprite.play_walk()
	if enemy.navigation_agent:
		enemy.navigation_agent.path_max_distance = 10
		enemy.navigation_agent.target_desired_distance = 10
		recalc_path()

func physics_update(delta: float):
	if !enemy.target or !enemy.navigation_agent:
		return
		
	if enemy.navigation_agent.is_navigation_finished():
		enemy.velocity = Vector2.ZERO
		return
	
	# Calculate direction to the next path position
	var next_path_position = enemy.navigation_agent.get_next_path_position()
	var direction = (next_path_position - enemy.global_position).normalized()
	enemy.character_sprite.current_direction = direction
	enemy.character_sprite.get_direction()
	enemy.navigation_agent.set_velocity(direction * speed)
	
	 #Attack transition check
	if target_in_attack_range:
		if enemy.id not in enemy.container.enemy_queue:
			if enemy.container.enemy_queue.size() < 5:
				enemy.container.enemy_queue.push_back(enemy.id)
				transition_requested.emit("AttackState")
				
func exit():
	enemy.velocity = Vector2.ZERO
	
func _on_attack_area_body_entered(body: Node2D):
	if body == enemy.target:
		target_in_attack_range = true
		
func _on_attack_area_body_exited(body: Node2D):
	if body == enemy.target:
		target_in_attack_range = false
		
func recalc_path():
	if enemy.target and enemy.navigation_agent:
		enemy.navigation_agent.target_position = enemy.target.global_position
		
func _on_recalc_path_timer_timeout() -> void:
	recalc_path()
	
func _on_navigation_agent_velocity_computed(safe_velocity: Vector2) -> void:
	if enemy.state_machine.current_state.name == "ChaseState":
		enemy.velocity = safe_velocity
