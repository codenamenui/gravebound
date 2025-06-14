extends Label

func _on_enemy_spawn_wave_started(wave_number: int) -> void:
	$".".text = str(SceneManager.game_world.get_node("Player").player_level)
