# attack_state.gd (updated)
class_name AttackState
extends State

@export var damage: int = 10
@export var attack_cooldown: float = 1.0
@export var chase_return_range: float = 70.0  # Slightly larger than attack range

var _attack_timer: float = 0.0

func enter(msg : Dictionary = {}) -> void:
	_attack_timer = attack_cooldown
	enemy.CharacterSprite.play_idle()

func physics_update(delta: float) -> void:
	if !enemy.target:
		transition_requested.emit("ChaseState")
		return
	
	if enemy.global_position.distance_to(enemy.target.global_position) > chase_return_range:
		transition_requested.emit("ChaseState")
		return
		
	if enemy.id in enemy.container.enemy_queue:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack()
			_attack_timer = attack_cooldown

func update(_delta):
	if enemy.id not in enemy.container.enemy_queue:
		if enemy.container.enemy_queue.size() < 5:
			enemy.container.enemy_queue.push_back(enemy.id)
		else:
			return

func _attack() -> void:
	#print(enemy.id)
	#print("old", enemy.container.enemy_queue)
	enemy.container.enemy_queue.pop_front()
	#print("new", enemy.container.enemy_queue)
	pass
