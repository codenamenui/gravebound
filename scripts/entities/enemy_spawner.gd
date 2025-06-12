extends Node2D

class_name WaveEnemySpawner

@export_group("Enemy Configuration")
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: Array[float] = []
@export var enemy_container: Node2D

@export_group("References")
@export var camera: Camera2D
@export var score_label: Label
@export var wave_label: Label
@export var navigation_map_rid: RID

@export_group("Spawn Settings")
@export var spawn_distance_from_camera: float = 150.0
@export var time_between_waves: float = 5.0
@export var max_enemies_alive: int = 10

@export_group("Wave Configuration")
@export var use_custom_waves: bool = false
@export var repeat_waves: bool = false
@export var custom_waves: Array[WaveData] = []

@export_group("Default Wave Settings")
@export var enemies_per_wave: int = 5
@export var spawn_interval: float = 2.0

var waves: Array = []
var current_wave_index: int = 0
var current_wave_enemies_spawned: int = 0
var current_enemies_alive: int = 0
var wave_active: bool = false
var current_score: int = 0
var id = 0

var spawn_timer: Timer
var wave_break_timer: Timer

class WaveData extends Resource:
	@export var enemy_count: int = 5
	@export var spawn_interval: float = 2.0
	@export var enemy_type_weights: Array[float] = []
	@export var wave_name: String = ""

func _ready():
	setup_timers()
	setup_waves()
	validate_references()
	connect_score_system()
	update_ui()
	start_waves()

func setup_timers():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	wave_break_timer = Timer.new()
	wave_break_timer.wait_time = time_between_waves
	wave_break_timer.one_shot = true
	wave_break_timer.timeout.connect(_on_wave_break_timeout)
	add_child(wave_break_timer)

func setup_waves():
	if use_custom_waves and not custom_waves.is_empty():
		waves = custom_waves.duplicate()
	else:
		setup_default_waves()

func setup_default_waves():
	waves = [
		create_wave_data(enemies_per_wave, spawn_interval, "Wave 1"),
		create_wave_data(enemies_per_wave + 2, max(spawn_interval - 0.2, 0.5), "Wave 2"),
		create_wave_data(enemies_per_wave + 4, max(spawn_interval - 0.4, 0.4), "Wave 3"),
		create_wave_data(enemies_per_wave + 6, max(spawn_interval - 0.6, 0.3), "Wave 4"),
		create_wave_data(enemies_per_wave + 8, max(spawn_interval - 0.8, 0.2), "Wave 5")
	]

func create_wave_data(count: int, interval: float, name: String = "") -> WaveData:
	var wave_data = WaveData.new()
	wave_data.enemy_count = count
	wave_data.spawn_interval = interval
	wave_data.wave_name = name
	wave_data.enemy_type_weights = enemy_weights.duplicate()
	return wave_data

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

	if enemy_weights.is_empty() and not enemy_scenes.is_empty():
		enemy_weights.resize(enemy_scenes.size())
		enemy_weights.fill(1.0)

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
		var wave_name = ""
		if current_wave_index < waves.size():
			var current_wave = waves[current_wave_index]
			if current_wave is WaveData and current_wave.wave_name != "":
				wave_name = current_wave.wave_name
			else:
				wave_name = "Wave " + str(current_wave_index + 1)
		else:
			wave_name = "Complete"
		wave_label.text = wave_name

func update_score_display():
	if score_label:
		score_label.text = str(current_score)

func start_waves():
	if waves.is_empty() or enemy_scenes.is_empty():
		return

	current_wave_index = 0
	current_wave_enemies_spawned = 0
	current_enemies_alive = 0
	_start_wave(0)

func stop_waves():
	wave_active = false
	spawn_timer.stop()
	wave_break_timer.stop()

func reset_waves():
	stop_waves()
	current_wave_index = 0
	current_wave_enemies_spawned = 0
	current_enemies_alive = 0
	current_score = 0
	update_ui()

func on_enemy_died(enemy: Node2D):
	current_enemies_alive = max(0, current_enemies_alive - 1)

func get_current_enemy_count() -> int:
	var actual_count = 0
	if enemy_container:
		actual_count = enemy_container.get_child_count()
	current_enemies_alive = max(current_enemies_alive, actual_count)
	return current_enemies_alive

func _start_wave(wave_index: int):
	if wave_index >= waves.size():
		if repeat_waves and not waves.is_empty():
			current_wave_index = 0
			_start_wave(0)
			return
		else:
			return

	var wave = waves[wave_index]
	current_wave_enemies_spawned = 0
	wave_active = true

	spawn_timer.wait_time = wave.spawn_interval
	spawn_timer.start()
	update_wave_display()

func _on_spawn_timer_timeout():
	_spawn_enemy()

func _on_wave_break_timeout():
	current_wave_index += 1
	_start_wave(current_wave_index)

func _spawn_enemy():
	if not wave_active or current_wave_index >= waves.size():
		return

	var current_wave = waves[current_wave_index]
	var enemy_count = current_wave.enemy_count

	if current_wave_enemies_spawned >= enemy_count:
		_complete_current_wave()
		return

	if get_current_enemy_count() >= max_enemies_alive:
		return

	var spawn_pos = _get_spawn_position_outside_camera()
	if spawn_pos == Vector2.ZERO:
		return

	var enemy_scene = _select_enemy_scene(current_wave)
	if not enemy_scene:
		return

	var enemy = _create_enemy_at_position(spawn_pos, enemy_scene)
	enemy.id = id
	id += 1
	
	if enemy:
		current_wave_enemies_spawned += 1
		current_enemies_alive += 1

		if enemy.has_signal("died"):
			enemy.died.connect(on_enemy_died.bind(enemy))
		elif enemy.has_signal("tree_exited"):
			enemy.tree_exited.connect(on_enemy_died.bind(enemy))

func _select_enemy_scene(wave_data) -> PackedScene:
	if enemy_scenes.is_empty():
		return null

	var weights = wave_data.enemy_type_weights if wave_data is WaveData and not wave_data.enemy_type_weights.is_empty() else enemy_weights

	if weights.is_empty():
		return enemy_scenes[randi() % enemy_scenes.size()]

	var total_weight = 0.0
	for weight in weights:
		total_weight += weight

	if total_weight <= 0.0:
		return enemy_scenes[randi() % enemy_scenes.size()]

	var random_value = randf() * total_weight
	var cumulative_weight = 0.0

	for i in range(min(enemy_scenes.size(), weights.size())):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return enemy_scenes[i]

	return enemy_scenes[0]

func _complete_current_wave():
	wave_active = false
	spawn_timer.stop()

	if current_wave_index < waves.size() - 1 or repeat_waves:
		wave_break_timer.start()
	else:
		update_wave_display()

func _create_enemy_at_position(pos: Vector2, scene: PackedScene) -> Node2D:
	if not scene or not enemy_container:
		return null

	var enemy = scene.instantiate()
	if not enemy:
		return null

	enemy.global_position = pos
	enemy.container = enemy_container
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
		0:
			spawn_pos = Vector2(
				randf_range(camera_bounds.position.x - spawn_distance_from_camera, 
						   camera_bounds.end.x + spawn_distance_from_camera),
				camera_bounds.position.y - spawn_distance_from_camera
			)
		1:
			spawn_pos = Vector2(
				camera_bounds.end.x + spawn_distance_from_camera,
				randf_range(camera_bounds.position.y - spawn_distance_from_camera,
						   camera_bounds.end.y + spawn_distance_from_camera)
			)
		2:
			spawn_pos = Vector2(
				randf_range(camera_bounds.position.x - spawn_distance_from_camera,
						   camera_bounds.end.x + spawn_distance_from_camera),
				camera_bounds.end.y + spawn_distance_from_camera
			)
		3:
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

func set_enemies_per_wave(count: int):
	enemies_per_wave = count

func set_max_enemies_alive(count: int):
	max_enemies_alive = count

func set_spawn_interval(interval: float):
	spawn_interval = interval
	if spawn_timer:
		spawn_timer.wait_time = interval

func add_custom_wave(enemy_count: int, spawn_interval_val: float = -1, wave_name: String = "", weights: Array[float] = []):
	var interval = spawn_interval_val if spawn_interval_val > 0 else spawn_interval
	var wave_data = WaveData.new()
	wave_data.enemy_count = enemy_count
	wave_data.spawn_interval = interval
	wave_data.wave_name = wave_name
	wave_data.enemy_type_weights = weights if not weights.is_empty() else enemy_weights.duplicate()
	custom_waves.append(wave_data)

func clear_custom_waves():
	custom_waves.clear()

func set_use_custom_waves(use_custom: bool):
	use_custom_waves = use_custom
	setup_waves()

func test_spawn_single_enemy():
	if enemy_scenes.is_empty():
		return

	var pos = _get_spawn_position_outside_camera()
	if pos != Vector2.ZERO:
		var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
		var enemy = _create_enemy_at_position(pos, enemy_scene)
		if enemy:
			current_enemies_alive += 1
