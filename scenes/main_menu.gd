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
