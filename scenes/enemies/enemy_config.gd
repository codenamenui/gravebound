class_name EnemySpawnConfig
extends Resource

@export var enemy_scene: PackedScene
@export_range(0.0, 1.0) var spawn_probability: float = 1.0
@export var max_count: int = -1  # -1 for unlimited
@export var enemy_name: String = ""  # Optional name for organization

# Runtime tracking (not exported)
var current_spawned_count: int = 0

func reset_count():
	current_spawned_count = 0

func can_spawn() -> bool:
	return max_count == -1 or current_spawned_count < max_count

func increment_count():
	current_spawned_count += 1
