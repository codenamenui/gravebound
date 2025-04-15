extends Node
class_name HealthComponent

signal health_depleted
signal health_changed(new_health)

@export var max_health: int = 100
var current_health: int = max_health
var is_invincible: bool = false

func take_damage(damage: int):
	if is_invincible:
		return
	
	current_health = max(current_health - damage, 0)
	health_changed.emit(current_health)
	
	if current_health <= 0:
		health_depleted.emit()
	else:
		# Brief invincibility after hit
		is_invincible = true
		await get_tree().create_timer(0.3).timeout
		is_invincible = false
