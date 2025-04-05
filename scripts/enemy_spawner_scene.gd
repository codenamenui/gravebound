extends Node2D

@export var enemy_scene: PackedScene
@onready var player = $Player
@onready var enemy_spawner = $EnemySpawner
@onready var ui = $UI

func _ready():
	# Configure the enemy spawner
	enemy_spawner.enemy_scene = enemy_scene
	enemy_spawner.player = player
	
	# Connect UI elements if they exist
	var spawn_button = ui.get_node_or_null("SpawnButton")
	if spawn_button:
		spawn_button.pressed.connect(_on_spawn_button_pressed)
	
	var clear_button = ui.get_node_or_null("ClearButton")
	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)
	
	var enemy_count_label = ui.get_node_or_null("EnemyCountLabel")
	if enemy_count_label:
		# Update enemy count label every second
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.timeout.connect(_update_enemy_count_label)
		add_child(timer)
		timer.start()

func _on_spawn_button_pressed():
	if enemy_spawner.is_spawning:
		enemy_spawner.stop_spawning()
	else:
		enemy_spawner.start_spawning()

func _on_clear_button_pressed():
	enemy_spawner.clear_all_enemies()

func _update_enemy_count_label():
	var enemy_count_label = ui.get_node_or_null("EnemyCountLabel")
	if enemy_count_label:
		enemy_count_label.text = "Active Enemies: " + str(enemy_spawner.get_active_enemy_count())
