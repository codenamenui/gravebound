extends Node

var ui_layer: CanvasLayer
var game_world: Node2D
var game_scene: Node
var ui_panels = {}
var is_initialized = false

func _ready():
	print("SceneManager autoload initializing...")
	call_deferred("initialize_scene_manager")

func initialize_scene_manager():
	await get_tree().process_frame
	
	game_scene = get_tree().current_scene
	if not game_scene:
		push_error("SceneManager: No current scene found")
		return
	
	print("Game scene found: ", game_scene.name)
	
	ui_layer = game_scene.get_node_or_null("UI")
	game_world = game_scene.get_node_or_null("GameWorld")
	
	if not ui_layer:
		push_error("SceneManager: Could not find UI node in scene")
		return
	
	if not game_world:
		push_error("SceneManager: Could not find GameWorld node in scene")
		return
	
	print("UI and GameWorld found successfully")
	cache_ui_panels()
	is_initialized = true
	
	hide_all_panels()
	await get_tree().process_frame
	transition_to_state(GameData.current_state)
	
	connect_signals()

func connect_signals():
	if GameData.wave_completed.is_connected(_on_wave_completed):
		GameData.wave_completed.disconnect(_on_wave_completed)
	if GameData.player_died.is_connected(_on_player_died):
		GameData.player_died.disconnect(_on_player_died)
	
	GameData.wave_completed.connect(_on_wave_completed)
	GameData.player_died.connect(_on_player_died)

func cache_ui_panels():
	var panel_names = ["MainMenu", "Settings", "GameHUD", "PerksPanel", "GameOverScreen", "PauseMenu"]
	
	for panel_name in panel_names:
		var panel = ui_layer.get_node_or_null(panel_name)
		if panel:
			ui_panels[panel_name] = panel
			print("Found panel: ", panel_name)
		else:
			print("Panel not found: ", panel_name)

func transition_to_state(new_state: GameData.GameState):
	if not is_initialized:
		print("SceneManager not initialized, deferring state transition")
		await get_tree().process_frame
		if not is_initialized:
			return
	
	print("SceneManager: Transitioning to state ", new_state)
	
	hide_all_panels()
	await get_tree().process_frame
	
	match new_state:
		GameData.GameState.MAIN_MENU:
			show_main_menu()
		GameData.GameState.PLAYING:
			show_game_hud()
			prepare_game_world()
		GameData.GameState.PERK_SELECTION:
			show_perks_panel()
		GameData.GameState.GAME_OVER:
			show_game_over_screen()
		GameData.GameState.SETTINGS:
			show_settings()
	
	GameData.current_state = new_state

func hide_all_panels():
	if not is_initialized:
		return
	
	print("Hiding all panels...")
	for panel_name in ui_panels.keys():
		var panel = ui_panels[panel_name]
		if is_instance_valid(panel):
			panel.visible = false
			panel.set_process_mode(Node.PROCESS_MODE_DISABLED)
			print("Hidden: ", panel_name)
	
	if is_instance_valid(game_world):
		game_world.visible = false
		game_world.set_process_mode(Node.PROCESS_MODE_DISABLED)
		print("Hidden: GameWorld")

func show_main_menu():
	print("Showing main menu")
	var main_menu = ui_panels.get("MainMenu")
	if is_instance_valid(main_menu):
		main_menu.visible = true
		main_menu.set_process_mode(Node.PROCESS_MODE_INHERIT)

func show_settings():
	print("Showing settings")
	var settings = ui_panels.get("Settings")
	if is_instance_valid(settings):
		settings.visible = true
		settings.set_process_mode(Node.PROCESS_MODE_INHERIT)

func show_game_hud():
	print("Showing game HUD")
	var game_hud = ui_panels.get("GameHUD")
	if is_instance_valid(game_hud):
		game_hud.visible = true
		game_hud.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if is_instance_valid(game_world):
		game_world.visible = true
		game_world.set_process_mode(Node.PROCESS_MODE_INHERIT)

func show_perks_panel():
	print("Showing perks panel")
	var perks_panel = ui_panels.get("PerksPanel")
	if is_instance_valid(perks_panel):
		if perks_panel.has_method("setup_perk_options"):
			perks_panel.setup_perk_options(GameData.current_wave)
		perks_panel.visible = true
		perks_panel.set_process_mode(Node.PROCESS_MODE_INHERIT)

func show_game_over_screen():
	print("Showing game over screen")
	var game_over = ui_panels.get("GameOverScreen")
	if is_instance_valid(game_over):
		if game_over.has_method("update_final_stats"):
			game_over.update_final_stats(GameData.total_score, GameData.current_wave - 1)
		game_over.visible = true
		game_over.set_process_mode(Node.PROCESS_MODE_INHERIT)

func prepare_game_world():
	if not is_instance_valid(game_world):
		return
	
	if GameData.current_wave == 1:
		reset_game_world()
	
	game_world.visible = true
	game_world.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if game_world.has_node("WaveManager"):
		var wave_manager = game_world.get_node("WaveManager")
		if wave_manager and wave_manager.has_method("start_wave"):
			wave_manager.start_wave(GameData.current_wave)

func reset_game_world():
	if not is_instance_valid(game_world):
		return
	
	if game_world.has_node("EnemyContainer"):
		var enemies_container = game_world.get_node("EnemyContainer")
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy):
				enemy.queue_free()

func _input(event):
	if not is_initialized:
		return
	
	if event.is_action_pressed("ui_cancel"):
		match GameData.current_state:
			GameData.GameState.SETTINGS:
				transition_to_state(GameData.GameState.MAIN_MENU)
			GameData.GameState.PLAYING:
				show_pause_menu()

func show_pause_menu():
	var pause_menu = ui_panels.get("PauseMenu")
	if is_instance_valid(pause_menu):
		get_tree().paused = true
		pause_menu.visible = true
		pause_menu.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)

func resume_game():
	var pause_menu = ui_panels.get("PauseMenu")
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
		get_tree().paused = false

func _on_wave_completed():
	transition_to_state(GameData.GameState.PERK_SELECTION)

func _on_player_died():
	transition_to_state(GameData.GameState.GAME_OVER)
