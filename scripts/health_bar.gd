extends Node2D

@export var healthComponent: HealthComponent
@onready var healthBar: TextureProgressBar = $"Health Bar"

func _ready() -> void:
	healthBar.min_value = 0
	healthBar.max_value = healthComponent.max_health
	healthBar.value = healthComponent.max_health

	healthComponent.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
	healthBar.value = new_health
