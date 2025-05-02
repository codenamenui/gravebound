# attack_state.gd (updated)
class_name AttackState
extends State

@export var damage: int = 10
@export var attack_cooldown: float = 1.0
@export var chase_return_range: float = 70.0  # Slightly larger than attack range

var _attack_timer: float = 0.0

func enter(msg : Dictionary = {}) -> void:
	_attack_timer = attack_cooldown

func physics_update(delta: float) -> void:
	if !enemy.target:
		transition_requested.emit("ChaseState")
		return
	
	if enemy.global_position.distance_to(enemy.target.global_position) > chase_return_range:
		transition_requested.emit("ChaseState")
		return
	
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack()
		_attack_timer = attack_cooldown

func _attack() -> void:
	# Your damage logic here
	pass
