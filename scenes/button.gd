extends Button

func _on_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PAUSED)
