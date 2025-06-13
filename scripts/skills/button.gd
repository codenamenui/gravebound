extends Node2D

func _on_touch_screen_button_pressed() -> void:
	$TouchScreenButton.modulate.a = 0.5

func _on_touch_screen_button_released() -> void:
	$TouchScreenButton.modulate.a = 1
