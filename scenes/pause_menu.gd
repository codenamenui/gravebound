extends Control

func _on_play_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PLAYING)

func _on_settings_pressed() -> void:
	GameData.from_game = true
	SceneManager.transition_to_state(GameData.GameState.SETTINGS)

#func _on_main_menu_pressed() -> void:
	#SceneManager.return_to_main_menu()
