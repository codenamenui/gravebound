extends Control

func _on_play_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PLAYING)

func _on_settings_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.SETTINGS)
