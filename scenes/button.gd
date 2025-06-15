extends Button

func _ready() -> void:
	$".".pressed.connect(func(): AudioManager.play_sfx("button_click"))
	$".".mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	
func _on_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PAUSED)
