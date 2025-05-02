extends Node2D
class_name HealthBar

@export var health_component: HealthComponent
@onready var health_bar: TextureProgressBar = $"Health Bar"

func _ready() -> void:
	if !health_component:
		push_error("HealthComponent not assigned to HealthBar!")
		return
	
	# Initialize health bar values
	health_bar.min_value = 0
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health
	
	# Connect signals
	health_component.health_changed.connect(_on_health_changed)
	health_component.took_damage.connect(_on_took_damage)

func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health
	# Optional: Add health bar animation here

func _on_took_damage(damage: int, knockback: Vector2):
	# Visual feedback when damage is taken
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
