extends Node
class_name HealthComponent

signal health_depleted
signal health_changed(new_health)
signal took_damage(damage, knockback_direction)

@export var max_health: int
@export var invincibility_duration: float = 0.5

@onready var current_health: int = max_health
@onready var init_max_health: int = max_health
var is_invincible: bool = false

func take_damage(damage: int):
	if is_invincible:
		return true

	current_health = current_health - damage
	health_changed.emit(current_health)
	
	if current_health <= 0:
		health_depleted.emit()
	else:
		_temp_invincibility()
		
	return false

func set_invincible(value: bool):
	is_invincible = value

func _temp_invincibility():
	is_invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	is_invincible = false

func add_current_health(bonus: int):
	current_health += bonus
	
func add_max_health(bonus: int):
	max_health += bonus

func reset_health():
	max_health = init_max_health

func heal(health: int):
	current_health += health
	if current_health > max_health:
		current_health = max_health
