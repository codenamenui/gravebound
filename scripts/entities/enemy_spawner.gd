extends Node2D

class_name WaveEnemySpawner

# Signals
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

@export_group("Enemy Configuration")
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_container: Node2D

@export_group("References")
@export var camera: Camera2D
@export var score_label: Label
@export var wave_label: Label
@export var navigation_map_rid: RID
@export var player: Player

@export_group("Spawn Settings")
@export var spawn_distance_from_camera: float = 150.0
@export var time_between_waves: float = 5.0

@export_group("Wave Progression")
@export var total_waves: int = 10
@export var infinite_waves: bool = false
@export var base_enemies_per_wave: int = 5
@export var enemies_per_wave_growth: float = 1.5  # Multiplier per wave
@export var max_enemies_per_wave: int = 50

@export_group("Spawn Timing")
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.3
@export var spawn_interval_decay: float = 0.9  # Multiplier per wave (gets faster)

@export_group("Enemy Alive Limits")
@export var base_max_enemies_alive: int = 8
@export var max_enemies_alive_growth: float = 1.2  # Multiplier per wave
@export var absolute_max_enemies_alive: int = 30

@export_group("Enemy Introduction System")
@export var enemy_introduction_waves: Array[int] = [1, 3, 5, 7]  # Which waves to introduce new enemy types
@export var probability_shift_speed: float = 0.15  # How fast probabilities shift toward newer enemies per wave

@export_group("Difficulty Curves")
@export var use_exponential_growth: bool = true  # vs linear growth
@export var difficulty_spike_waves: Array[int] = [5, 10, 15]  # Waves with extra difficulty
@export var spike_multiplier: float = 1.5

@export_group("Level Up System")
@export var base_points_per_level: int = 100
@export var points_scaling_factor: float = 1.1

# Runtime variables
var current_wave_index: int = 0
var current_wave_enemies_spawned: int = 0
var current_enemies_alive: int = 0
var wave_active: bool = false
var waiting_for_wave_clear: bool = false
var current_score: int = 0
var wave_start_score: int = 0
var id = 0

var spawn_timer: Timer
var wave_break_timer: Timer
var is_paused: bool = false
var waiting_to_continue: bool = false

# Calculated wave properties
var current_wave_enemy_count: int
var current_wave_spawn_interval: float
var current_wave_max_alive: int
var available_enemy_types: Array[PackedScene] = []
var enemy_probabilities: Array[float] = []

func _ready():
	setup_timers()
	validate_references()
	connect_score_system()
	update_ui()

func setup_timers():
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	wave_break_timer = Timer.new()
	wave_break_timer.wait_time = time_between_waves
	wave_break_timer.one_shot = true
	wave_break_timer.timeout.connect(_on_wave_break_timeout)
	add_child(wave_break_timer)

func validate_references():
	if not enemy_container:
		var container = get_node_or_null("../EnemyContainer")
		if container:
			enemy_container = container
		else:
			enemy_container = Node2D.new()
			enemy_container.name = "EnemyContainer"
			get_parent().add_child(enemy_container)

	if not camera:
		camera = get_viewport().get_camera_2d()

	if not navigation_map_rid.is_valid():
		navigation_map_rid = get_world_2d().get_navigation_map()

func connect_score_system():
	if enemy_container and enemy_container.has_signal("enemy_points_awarded"):
		if not enemy_container.enemy_points_awarded.is_connected(_on_points_awarded):
			enemy_container.enemy_points_awarded.connect(_on_points_awarded)

func _on_points_awarded(points: int):
	current_score += points
	update_score_display()

func update_ui():
	update_wave_display()
	update_score_display()

func update_wave_display():
	if wave_label:
		if current_wave_index < total_waves or infinite_waves:
			wave_label.text = "Wave " + str(current_wave_index + 1)
		else:
			wave_label.text = "Complete"

func update_score_display():
	if score_label:
		score_label.text = str(current_score)

func start_waves():
	if enemy_scenes.is_empty():
		push_warning("No enemy scenes configured for WaveEnemySpawner")
		return
	
	current_wave_index = 0
	current_wave_enemies_spawned = 0
	current_enemies_alive = 0
	waiting_for_wave_clear = false
	_start_wave(0)

func stop_waves():
	wave_active = false
	waiting_for_wave_clear = false
	spawn_timer.stop()
	wave_break_timer.stop()

func reset_spawner():
	"""Reset the spawner to initial state"""
	stop_waves()
	
	# Reset counters
	current_wave_index = 0
	current_wave_enemies_spawned = 0
	current_enemies_alive = 0
	current_score = 0
	wave_start_score = 0
	id = 0
	waiting_for_wave_clear = false
	
	# Clear existing enemies
	if enemy_container:
		for child in enemy_container.get_children():
			child.queue_free()
	
	update_ui()

func _calculate_wave_properties(wave_number: int):
	"""Calculate all properties for the given wave number (0-indexed)"""
	var wave_num = wave_number + 1  # Make it 1-indexed for calculations
	
	# Calculate enemy count
	if use_exponential_growth:
		current_wave_enemy_count = int(base_enemies_per_wave * pow(enemies_per_wave_growth, wave_number))
	else:
		current_wave_enemy_count = base_enemies_per_wave + int(wave_number * (enemies_per_wave_growth - 1.0) * base_enemies_per_wave)
	
	# Apply difficulty spikes
	if wave_num in difficulty_spike_waves:
		current_wave_enemy_count = int(current_wave_enemy_count * spike_multiplier)
	
	current_wave_enemy_count = min(current_wave_enemy_count, max_enemies_per_wave)
	
	# Calculate spawn interval
	current_wave_spawn_interval = max(base_spawn_interval * pow(spawn_interval_decay, wave_number), min_spawn_interval)
	
	# Calculate max enemies alive
	if use_exponential_growth:
		current_wave_max_alive = int(base_max_enemies_alive * pow(max_enemies_alive_growth, wave_number))
	else:
		current_wave_max_alive = base_max_enemies_alive + int(wave_number * (max_enemies_alive_growth - 1.0) * base_max_enemies_alive)
	
	# Apply difficulty spikes to max alive
	if wave_num in difficulty_spike_waves:
		current_wave_max_alive = int(current_wave_max_alive * spike_multiplier)
	
	current_wave_max_alive = min(current_wave_max_alive, absolute_max_enemies_alive)
	
	# Calculate available enemy types based on introduction waves
	_update_available_enemies(wave_num)
	
	# Calculate enemy probabilities
	_calculate_enemy_probabilities(wave_number)

func _update_available_enemies(wave_num: int):
	"""Update which enemy types are available based on introduction waves"""
	available_enemy_types.clear()
	
	# Add enemy types based on introduction waves
	var enemies_to_add = 1  # Always have at least the first enemy type
	
	for intro_wave in enemy_introduction_waves:
		if wave_num >= intro_wave:
			enemies_to_add += 1
	
	# Ensure we don't exceed available enemy scenes
	enemies_to_add = min(enemies_to_add, enemy_scenes.size())
	
	for i in range(enemies_to_add):
		if i < enemy_scenes.size() and enemy_scenes[i]:
			available_enemy_types.append(enemy_scenes[i])

func _calculate_enemy_probabilities(wave_number: int):
	"""Calculate spawn probabilities for each available enemy type"""
	enemy_probabilities.clear()
	
	if available_enemy_types.is_empty():
		return
	
	var num_types = available_enemy_types.size()
	enemy_probabilities.resize(num_types)
	
	if num_types == 1:
		enemy_probabilities[0] = 1.0
		return
	
	# Base probability for equal distribution
	var base_prob = 1.0 / float(num_types)
	
	# Calculate probability shift - newer enemies get higher probability over time
	var shift_factor = wave_number * probability_shift_speed
	
	for i in range(num_types):
		# Newer enemies (higher index) get bonus probability
		var bonus = (float(i) / float(num_types - 1)) * shift_factor
		enemy_probabilities[i] = base_prob + bonus
	
	# Normalize probabilities to sum to 1.0
	var total_prob = 0.0
	for prob in enemy_probabilities:
		total_prob += prob
	
	if total_prob > 0.0:
		for i in range(enemy_probabilities.size()):
			enemy_probabilities[i] /= total_prob

func _start_wave(wave_index: int):
	if not infinite_waves and wave_index >= total_waves:
		all_waves_completed.emit()
		return
	
	AudioManager.play_sfx("wave_start")
	
	current_wave_index = wave_index
	current_wave_enemies_spawned = 0
	waiting_for_wave_clear = false
	wave_active = true
	wave_start_score = current_score
	
	# Calculate properties for this wave
	_calculate_wave_properties(wave_index)
	
	# Start spawning
	spawn_timer.wait_time = current_wave_spawn_interval
	spawn_timer.start()
	update_wave_display()
	
	# Emit wave started signal
	wave_started.emit(wave_index + 1)
	if (wave_index + 1) % 2 == 0:
		AudioManager.play_music("gameplay_intense")
	else:
		AudioManager.play_music("gameplay")
		
	# Debug info
	print("Wave ", wave_index + 1, " started:")
	print("  Enemies to spawn: ", current_wave_enemy_count)
	print("  Spawn interval: ", current_wave_spawn_interval)
	print("  Max alive: ", current_wave_max_alive)
	print("  Available enemy types: ", available_enemy_types.size())

func _on_spawn_timer_timeout():
	if is_paused:
		return
	_spawn_enemy()

func _on_wave_break_timeout():
	current_wave_index += 1
	_start_wave(current_wave_index)

func _spawn_enemy():
	if not wave_active or is_paused:
		return
	
	# Check if we've spawned all enemies for this wave
	if current_wave_enemies_spawned >= current_wave_enemy_count:
		# Stop spawning and wait for all enemies to die
		wave_active = false
		spawn_timer.stop()
		waiting_for_wave_clear = true
		
		# If no enemies are alive, complete immediately
		if current_enemies_alive == 0:
			_complete_current_wave()
		return

	# Check if we've reached the max alive limit
	if get_current_enemy_count() >= current_wave_max_alive:
		return

	var spawn_pos = _get_spawn_position_outside_camera()
	if spawn_pos == Vector2.ZERO:
		return

	var enemy_scene = _select_enemy_scene()
	if not enemy_scene:
		return

	var enemy = _create_enemy_at_position(spawn_pos, enemy_scene)
	if enemy:
		enemy.id = id
		id += 1
		
		current_wave_enemies_spawned += 1
		current_enemies_alive += 1

		if enemy.has_signal("died"):
			enemy.died.connect(on_enemy_died.bind(enemy))
		elif enemy.has_signal("tree_exited"):
			enemy.tree_exited.connect(on_enemy_died.bind(enemy))

func _select_enemy_scene() -> PackedScene:
	if available_enemy_types.is_empty() or enemy_probabilities.is_empty():
		return null
	
	# Select enemy based on weighted probabilities
	var random_value = randf()
	var cumulative_prob = 0.0
	
	for i in range(available_enemy_types.size()):
		cumulative_prob += enemy_probabilities[i]
		if random_value <= cumulative_prob:
			return available_enemy_types[i]
	
	# Fallback to last enemy type
	return available_enemy_types[-1]

func on_enemy_died(enemy: Node2D):
	current_enemies_alive = max(0, current_enemies_alive - 1)
	
	# Check if wave should be completed (all enemies spawned and all died)
	if waiting_for_wave_clear and current_enemies_alive == 0:
		_complete_current_wave()

func get_current_enemy_count() -> int:
	var actual_count = 0
	if enemy_container:
		actual_count = enemy_container.get_child_count()
	current_enemies_alive = max(current_enemies_alive, actual_count)
	return current_enemies_alive

func _complete_current_wave():
	waiting_for_wave_clear = false
	
	var wave_points = current_score - wave_start_score
	var level_amount = _calculate_level_amount(wave_points)
	
	if player and player.has_method("level_up"):
		player.level_up(level_amount)
	
	GameData.current_wave += 1
	
	SceneManager.transition_to_state(GameData.GameState.PERK_SELECTION)
	wave_completed.emit(current_wave_index + 1)

	
	if infinite_waves or current_wave_index < total_waves - 1:
		is_paused = true
		waiting_to_continue = true
		AudioManager.play_sfx("wave_complete")
		print("Wave ", current_wave_index + 1, " completed. Waiting for perk selection...")
	else:
		update_wave_display()
		all_waves_completed.emit()

func _calculate_level_amount(points: int) -> int:
	var points_needed = base_points_per_level * pow(points_scaling_factor, current_wave_index)
	return max(1, int(points / points_needed))

func pause_waves():
	"""Pause wave spawning (can be called anytime)"""
	is_paused = true
	spawn_timer.stop()
	wave_break_timer.stop()

func continue_waves():
	"""Continue to the next wave after perk selection"""
	if not waiting_to_continue:
		return
	
	is_paused = false
	waiting_to_continue = false
	
	# Start the break timer for next wave
	wave_break_timer.start()

func is_waves_paused() -> bool:
	return is_paused
	
func _create_enemy_at_position(pos: Vector2, scene: PackedScene) -> Node2D:
	if not scene or not enemy_container:
		return null

	var enemy: Enemy = scene.instantiate()
	if not enemy:
		return null

	enemy.global_position = pos
	enemy.container = enemy_container
	enemy.target = player
	enemy.set_wave_number(current_wave_index + 1)
	enemy_container.add_child(enemy)
	return enemy

func _get_spawn_position_outside_camera() -> Vector2:
	if not camera:
		return global_position + Vector2(spawn_distance_from_camera, 0)

	var camera_pos = camera.global_position
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_factor = camera.zoom
	var visible_size = viewport_size / zoom_factor
	var half_visible = visible_size * 0.5
	var camera_bounds = Rect2(camera_pos - half_visible, visible_size)
	var spawn_side = randi() % 4
	var spawn_pos: Vector2

	match spawn_side:
		0: # Top
			spawn_pos = Vector2(
				randf_range(camera_bounds.position.x - spawn_distance_from_camera, 
						   camera_bounds.end.x + spawn_distance_from_camera),
				camera_bounds.position.y - spawn_distance_from_camera
			)
		1: # Right
			spawn_pos = Vector2(
				camera_bounds.end.x + spawn_distance_from_camera,
				randf_range(camera_bounds.position.y - spawn_distance_from_camera,
						   camera_bounds.end.y + spawn_distance_from_camera)
			)
		2: # Bottom
			spawn_pos = Vector2(
				randf_range(camera_bounds.position.x - spawn_distance_from_camera,
						   camera_bounds.end.x + spawn_distance_from_camera),
				camera_bounds.end.y + spawn_distance_from_camera
			)
		3: # Left
			spawn_pos = Vector2(
				camera_bounds.position.x - spawn_distance_from_camera,
				randf_range(camera_bounds.position.y - spawn_distance_from_camera,
						   camera_bounds.end.y + spawn_distance_from_camera)
			)

	if navigation_map_rid.is_valid() and not _is_position_walkable(spawn_pos):
		for attempt in range(20):
			match spawn_side:
				0, 2:
					spawn_pos.x = randf_range(camera_bounds.position.x - spawn_distance_from_camera, camera_bounds.end.x + spawn_distance_from_camera)
				1, 3:
					spawn_pos.y = randf_range(camera_bounds.position.y - spawn_distance_from_camera, camera_bounds.end.y + spawn_distance_from_camera)

			if _is_position_walkable(spawn_pos):
				break
		
		if not _is_position_walkable(spawn_pos):
			return Vector2.ZERO

	return spawn_pos

func _is_position_walkable(pos: Vector2) -> bool:
	if not navigation_map_rid.is_valid():
		return true
	
	var closest_point = NavigationServer2D.map_get_closest_point(navigation_map_rid, pos)
	var distance_to_nav = pos.distance_to(closest_point)
	
	return distance_to_nav <= 0

func set_score(score: int):
	current_score = score
	update_score_display()

func add_score(points: int):
	current_score += points
	update_score_display()

func get_score() -> int:
	return current_score

func get_current_wave_number() -> int:
	return current_wave_index + 1

func get_enemies_remaining_to_spawn() -> int:
	return current_wave_enemy_count - current_wave_enemies_spawned

func is_waiting_for_wave_clear() -> bool:
	return waiting_for_wave_clear

func get_current_wave_stats() -> Dictionary:
	"""Get detailed stats about the current wave"""
	return {
		"wave_number": current_wave_index + 1,
		"total_enemies": current_wave_enemy_count,
		"enemies_spawned": current_wave_enemies_spawned,
		"enemies_remaining": get_enemies_remaining_to_spawn(),
		"enemies_alive": current_enemies_alive,
		"max_enemies_alive": current_wave_max_alive,
		"spawn_interval": current_wave_spawn_interval,
		"available_enemy_types": available_enemy_types.size(),
		"enemy_probabilities": enemy_probabilities.duplicate()
	}

func preview_wave_stats(wave_number: int) -> Dictionary:
	"""Preview stats for any wave number (1-indexed)"""
	var old_wave = current_wave_index
	_calculate_wave_properties(wave_number - 1)
	var stats = {
		"wave_number": wave_number,
		"total_enemies": current_wave_enemy_count,
		"max_enemies_alive": current_wave_max_alive,
		"spawn_interval": current_wave_spawn_interval,
		"available_enemy_types": available_enemy_types.size(),
		"enemy_probabilities": enemy_probabilities.duplicate()
	}
	# Restore original wave calculations
	if old_wave >= 0:
		_calculate_wave_properties(old_wave)
	return stats
