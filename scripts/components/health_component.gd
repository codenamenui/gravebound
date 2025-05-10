extends Node
class_name HealthComponent

signal health_depleted
signal health_changed(new_health)
signal took_damage(damage, knockback_direction)

@export var max_health: int = 100
@export var invincibility_duration: float = 0.5

var current_health: int = max_health
var is_invincible: bool = false

func take_damage(damage: int):
	if is_invincible:
		return
	
	current_health = max(current_health - damage, 0)
	health_changed.emit(current_health)
	
	## Calculate knockback direction
	#var knockback_direction = (owner.global_position - source_position).normalized()
	#took_damage.emit(damage, knockback_direction)
	
	if current_health <= 0:
		health_depleted.emit()
	else:
		_temp_invincibility()

func set_invincible(value: bool):
	is_invincible = value

func _temp_invincibility():
	is_invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false
