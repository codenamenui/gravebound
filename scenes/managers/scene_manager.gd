extends Node

var ui_layer: CanvasLayer
var game_world: GameWorld
var game_scene: Node
var ui_panels = {}
var is_initialized = false

func _ready():
	call_deferred("initialize_scene_manager")

func initialize_scene_manager():
	await get_tree().process_frame
	
	game_scene = get_tree().current_scene
	if not game_scene:
		push_error("SceneManager: No current scene found")
		return
	
	ui_layer = game_scene.get_node_or_null("UI")
	game_world = game_scene.get_node_or_null("GameWorld")
	
	if not ui_layer:
		push_error("SceneManager: Could not find UI node in scene")
		return
	
	if not game_world:
		push_error("SceneManager: Could not find GameWorld node in scene")
		return
	
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

func transition_to_state(new_state: GameData.GameState):
	if not is_initialized:
		await get_tree().process_frame
		if not is_initialized:
			return
	
	var previous_state = GameData.current_state
	GameData.previous_state = GameData.current_state
	
	if new_state != GameData.GameState.PAUSED:
		hide_all_panels()
		await get_tree().process_frame
	
	if new_state == GameData.GameState.PAUSED and previous_state == GameData.GameState.SETTINGS:
		hide_all_panels(true)
		await get_tree().process_frame
	
	if new_state == GameData.GameState.PLAYING and previous_state == GameData.GameState.PAUSED:
		get_tree().paused = false
		hide_pause_menu()
		show_game_hud()
		prepare_game_world()
		GameData.current_state = new_state
		return
	
	if new_state == GameData.GameState.MAIN_MENU and (previous_state == GameData.GameState.GAME_OVER or previous_state == GameData.GameState.PAUSED):
		reset_game_world()
		hide_all_panels()
		show_main_menu()
		reset_game_data()
		reset_game_hud()
		return
	
	if new_state == GameData.GameState.PLAYING and previous_state == GameData.GameState.PERK_SELECTION:
		hide_all_panels()
		game_world.EnemySpawner.continue_waves()
		show_game_hud()
		return
		
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
		GameData.GameState.PAUSED:
			show_pause_menu()
	
	GameData.current_state = new_state

func reset_game_data():
	GameData.current_state = GameData.GameState.MAIN_MENU
	GameData.current_wave = 0
	GameData.from_game = false
	GameData.from_pause = false

func reset_game_hud():
	pass
	
func hide_all_panels(edge_case: bool = false):
	if not is_initialized:
		return
	
	for panel_name in ui_panels.keys():
		var panel = ui_panels[panel_name]
		if is_instance_valid(panel):
			panel.visible = false
			panel.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	if is_instance_valid(game_world) and GameData.current_state != GameData.GameState.PAUSED:
		game_world.visible = false
		game_world.set_process_mode(Node.PROCESS_MODE_DISABLED)
		
	if edge_case and is_instance_valid(game_world):
		game_world.visible = true

func show_main_menu():
	var main_menu = ui_panels.get("MainMenu")
	if is_instance_valid(main_menu):
		main_menu.visible = true
		main_menu.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if is_instance_valid(game_world):
		game_world.visible = false
		game_world.set_process_mode(Node.PROCESS_MODE_DISABLED)

func show_settings():
	var settings = ui_panels.get("Settings")
	if is_instance_valid(settings):
		settings.visible = true
		if GameData.current_state == GameData.GameState.PAUSED or get_tree().paused:
			settings.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)
			if is_instance_valid(ui_layer):
				ui_layer.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)
		else:
			settings.set_process_mode(Node.PROCESS_MODE_INHERIT)

func show_game_hud():
	var game_hud = ui_panels.get("GameHUD")
	if is_instance_valid(game_hud):
		game_hud.visible = true
		game_hud.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if is_instance_valid(ui_layer):
		ui_layer.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	if is_instance_valid(game_world):
		game_world.visible = true
		game_world.set_process_mode(Node.PROCESS_MODE_INHERIT)
		enable_game_world_recursively(game_world)

func show_perks_panel():
	var perks_panel: PerkSelectionUI = ui_panels.get("PerksPanel")
	
	if is_instance_valid(game_world):
		game_world.visible = true
		game_world.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	perks_panel._select_random_perks(3)
	perks_panel.show_perk_selection(perks_panel.player)
	
func show_game_over_screen():
	var game_over = ui_panels.get("GameOverScreen")
	if is_instance_valid(game_over):
		if game_over.has_method("update_final_stats"):
			game_over.update_final_stats(GameData.total_score, GameData.current_wave - 1)
		game_over.visible = true
		game_over.set_process_mode(Node.PROCESS_MODE_INHERIT)

func prepare_game_world():
	if not is_instance_valid(game_world):
		return
	
	AudioManager.play_music("gameplay")
	
	if GameData.current_wave == 0:
		reset_game_world()
	
	game_world.visible = true
	game_world.set_process_mode(Node.PROCESS_MODE_INHERIT)
	enable_game_world_recursively(game_world)
	
	get_tree().paused = false
	
	game_world.EnemySpawner.start_waves()

func enable_game_world_recursively(node: Node):
	if not is_instance_valid(node):
		return
	
	node.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	for child in node.get_children():
		enable_game_world_recursively(child)

func reset_game_world():
	if not is_instance_valid(game_world):
		return
	
	if game_world.has_node("EnemyContainer"):
		var enemies_container = game_world.get_node("EnemyContainer")
		for enemy in enemies_container.get_children():
			if is_instance_valid(enemy):
				enemy.queue_free()
	
	if game_world.has_node("Player"):
		var player = game_world.get_node("Player")
		if player and player.has_method("reset_player"):
			player.reset_player()

func _input(event):
	if not is_initialized:
		return
	if event.is_action_pressed("ui_cancel"):
		match GameData.current_state:
			GameData.GameState.SETTINGS:
				transition_to_state(GameData.GameState.MAIN_MENU)
				return
			GameData.GameState.PLAYING:
				transition_to_state(GameData.GameState.PAUSED)
				return
			GameData.GameState.PAUSED:
				resume_game()
				return

func show_pause_menu():
	var pause_menu = ui_panels.get("PauseMenu")
	if is_instance_valid(pause_menu):
		get_tree().paused = true
		pause_menu.visible = true
		pause_menu.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)
		if is_instance_valid(ui_layer):
			ui_layer.set_process_mode(Node.PROCESS_MODE_WHEN_PAUSED)

func hide_pause_menu():
	var pause_menu = ui_panels.get("PauseMenu")
	if is_instance_valid(pause_menu):
		pause_menu.visible = false
		pause_menu.set_process_mode(Node.PROCESS_MODE_DISABLED)

func resume_game():
	transition_to_state(GameData.GameState.PLAYING)

func _on_wave_completed():
	transition_to_state(GameData.GameState.PERK_SELECTION)

func _on_player_died():
	transition_to_state(GameData.GameState.GAME_OVER)
