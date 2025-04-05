extends Node2D
class_name EnemySpawner

# Enemy scene to spawn
@export var enemy_scene: PackedScene
# Player reference - can be assigned in editor or found at runtime
@export var player: Node2D
# Minimum spawn distance from player
@export var min_spawn_distance: float = 300.0
# Maximum spawn distance from player
@export var max_spawn_distance: float = 500.0
# Time between spawn cycles in seconds
@export var spawn_interval: float = 5.0
# How many enemies to spawn per cycle
@export var enemies_per_cycle: int = 3
# Maximum number of enemies that can be active at once (0 = unlimited)
@export var max_concurrent_enemies: int = 15
# Should enemies be spawned randomly or evenly distributed?
@export_enum("Random", "Evenly Distributed") var spawn_pattern: int = 0
# Whether to start spawning immediately on ready
@export var auto_start: bool = true

# Timer for spawn cycles
var spawn_timer: Timer
# Container node for spawned enemies
var enemy_container: Node
# Whether spawning is currently active
var is_spawning: bool = false
# Count of currently active enemies
var active_enemy_count: int = 0

func _ready():
	# Create a timer for spawning
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Create a container for the enemies
	enemy_container = Node.new()
	enemy_container.name = "EnemyContainer"
	add_child(enemy_container)
	
	# Find player if not set
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			push_error("EnemySpawner: No player reference found!")
			return
	
	if auto_start:
		start_spawning()

func start_spawning():
	if player != null:
		is_spawning = true
		spawn_timer.start()
		# Do an initial spawn immediately
		spawn_enemies()

func stop_spawning():
	is_spawning = false
	spawn_timer.stop()

func spawn_enemies():
	if not is_spawning or player == null:
		return
	
	# Check if we've reached the max concurrent enemies
	if max_concurrent_enemies > 0 and active_enemy_count >= max_concurrent_enemies:
		return
	
	# Calculate how many enemies we can spawn this cycle
	var enemies_to_spawn = enemies_per_cycle
	if max_concurrent_enemies > 0:
		enemies_to_spawn = min(enemies_to_spawn, max_concurrent_enemies - active_enemy_count)
	
	match spawn_pattern:
		0: # Random
			_spawn_random(enemies_to_spawn)
		1: # Evenly Distributed
			_spawn_distributed(enemies_to_spawn)

func _spawn_random(count: int):
	for i in range(count):
		# Random angle
		var angle = randf() * 2 * PI
		# Random distance within range
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		# Calculate position
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Spawn the enemy
		_spawn_enemy(spawn_pos)

func _spawn_distributed(count: int):
	# Distribute enemies evenly in a circle around the player
	var angle_step = 2 * PI / count
	var start_angle = randf() * 2 * PI # Random starting angle for variety
	
	for i in range(count):
		var angle = start_angle + i * angle_step
		# Use average of min and max for consistent distance
		var distance = (min_spawn_distance + max_spawn_distance) / 2.0
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Spawn the enemy
		_spawn_enemy(spawn_pos)

func _spawn_enemy(position: Vector2):
	if enemy_scene == null:
		push_error("EnemySpawner: No enemy scene set!")
		return
	
	var enemy_instance = enemy_scene.instantiate()
	enemy_container.add_child(enemy_instance)
	enemy_instance.global_position = position
	
	# Connect to enemy's deletion signal to track active count
	if enemy_instance.has_signal("tree_exiting"):
		enemy_instance.tree_exiting.connect(_on_enemy_tree_exiting)
	else:
		# If the signal doesn't exist, we can connect to the component that manages health
		var health_component = enemy_instance.get_node_or_null("HealthComponent")
		if health_component and health_component.has_signal("health_depleted"):
			health_component.health_depleted.connect(_on_enemy_health_depleted.bind(enemy_instance))
	
	active_enemy_count += 1

func _on_enemy_tree_exiting():
	active_enemy_count = max(0, active_enemy_count - 1)

func _on_enemy_health_depleted(enemy_instance):
	# This will be called when the enemy's health is depleted but before they're removed
	# We'll decrement the counter when they're actually removed
	pass

func _on_spawn_timer_timeout():
	spawn_enemies()

# Public methods for external control
func set_spawn_interval(interval: float):
	spawn_interval = max(0.1, interval)
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval

func set_enemies_per_cycle(count: int):
	enemies_per_cycle = max(1, count)

func get_active_enemy_count() -> int:
	return active_enemy_count

func clear_all_enemies():
	# Remove all spawned enemies
	for child in enemy_container.get_children():
		child.queue_free()
	active_enemy_count = 0
