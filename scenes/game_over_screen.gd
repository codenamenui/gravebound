extends Control

func _on_main_menu_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.MAIN_MENU)

func _on_retry_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PLAYING)
