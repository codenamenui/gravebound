extends Control

func _on_play_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PLAYING)

func _on_settings_pressed() -> void:
	# Set flag to indicate we're coming from main menu (not pause menu)
	GameData.from_game = false
	SceneManager.transition_to_state(GameData.GameState.SETTINGS)

# Add this function if you want to handle returning to main menu from pause
func _on_main_menu_pressed() -> void:
	SceneManager.return_to_main_menu()

func get_all_buttons(node: Node) -> Array:
	var buttons = []
	for child in node.get_children():
		if child is Button:
			buttons.append(child)
		buttons += get_all_buttons(child)
	return buttons

func _ready():
	for button in get_all_buttons(self):
		button.pressed.connect(func(): AudioManager.play_ui_sound("button_click"))
		button.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
