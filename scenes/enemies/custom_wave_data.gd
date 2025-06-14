class_name CustomWaveData
extends Resource

@export var wave_name: String = "Custom Wave"
@export var total_enemies_to_spawn: int = 5
@export_range(0.1, 10.0) var spawn_interval: float = 2.0
@export var max_enemies_alive: int = 10
@export var enemy_spawn_configs: Array[EnemySpawnConfig] = []

func reset_spawn_counts():
	for config in enemy_spawn_configs:
		if config:
			config.reset_count()

func get_total_probability() -> float:
	var total: float = 0.0
	for config in enemy_spawn_configs:
		if config and config.can_spawn():
			total += config.spawn_probability
	return total

func get_available_configs() -> Array[EnemySpawnConfig]:
	var available: Array[EnemySpawnConfig] = []
	for config in enemy_spawn_configs:
		if config and config.can_spawn():
			available.append(config)
	return available
