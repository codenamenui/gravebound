extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer  # Changed to AudioStreamPlayer
@onready var ui_player: AudioStreamPlayer = $UIPlayer      # Changed to AudioStreamPlayer
@onready var sfx_pool: Node = $SFXPool

# Increased default volumes and added volume boost
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
var master_volume: float = 1.0
var volume_boost: float = 1.5  # Global volume multiplier

var current_music: String = ""
var music_tracks: Dictionary = {}
var sfx_sounds: Dictionary = {}
var ui_sounds: Dictionary = {}

var sfx_players: Array[AudioStreamPlayer] = []  # Changed to AudioStreamPlayer
var current_sfx_index: int = 0

func _ready():
	setup_sfx_pool()
	load_audio_resources()
	load_volume_settings()
	update_all_volumes()

func setup_sfx_pool():
	for i in range(8):
		var player = AudioStreamPlayer.new()  # Changed to AudioStreamPlayer
		player.name = "SFXPlayer" + str(i)
		sfx_pool.add_child(player)
		sfx_players.append(player)

func load_audio_resources():
	music_tracks = {
		"menu": preload("res://audio/music/main_menu.mp3"),
		"gameplay": preload("res://audio/music/gameplay.mp3"),
		"gameplay_intense": preload("res://audio/music/gameplay_intense.mp3"),
		"perk_selection": preload("res://audio/music/perk_selection.mp3"),
		"game_over": preload("res://audio/music/game_over.mp3")
	}
	
	sfx_sounds = {
		"player_shoot": preload("res://audio/sfx/player_shoot.wav"),
		"player_short_slash": preload("res://audio/sfx/short_slash.mp3"),
		"player_heavy_downlash": preload("res://audio/sfx/heavy_downlash.mp3"),
		"player_hurt": preload("res://audio/sfx/player_hurt.mp3"),
		"player_walk": preload("res://audio/sfx/player_walk.ogg"),
		"enemy_death": preload("res://audio/sfx/enemy_death.wav"),
		"enemy_spawn": preload("res://audio/sfx/enemy_spawn.mp3"),
		"enemy_range_attack": preload("res://audio/sfx/enemy_range_attack.mp3"),
		"enemy_melee_attack": preload("res://audio/sfx/enemy_melee_attack.mp3"),
		"enemy_mage_attack": preload("res://audio/sfx/enemy_mage_attack.mp3"),
		"enemy_cat_attack": preload("res://audio/sfx/enemy_cat_attack.mp3"),
		"pickup_collect": preload("res://audio/sfx/pickup_collect.mp3"),
		"wave_complete": preload("res://audio/sfx/wave_complete.mp3"),
		"wave_start": preload("res://audio/sfx/wave_start.mp3"),
		"explosion": preload("res://audio/sfx/explosion.mp3"),
		"perk_select": preload("res://audio/sfx/perk_select.mp3")
	}
	
	ui_sounds = {
		"button_click": preload("res://audio/ui/button_click.mp3"),
		"button_hover": preload("res://audio/ui/button_hover.mp3"),
		"menu_open": preload("res://audio/ui/menu_open.mp3"),
		"menu_close": preload("res://audio/ui/menu_close.mp3"),
		"error": preload("res://audio/ui/error.mp3")
	}

func play_music(track_name: String, fade_duration: float = 1.0):
	if current_music == track_name:
		return
	
	if not music_tracks.has(track_name):
		return
	
	current_music = track_name
	
	if music_player.playing:
		fade_out_music(fade_duration * 0.5)
		await get_tree().create_timer(fade_duration * 0.5).timeout
	
	music_player.stream = music_tracks[track_name]
	music_player.play()
	fade_in_music(fade_duration * 0.5)

func stop_music(fade_duration: float = 1.0):
	if fade_duration > 0:
		fade_out_music(fade_duration)
		await get_tree().create_timer(fade_duration).timeout
	music_player.stop()
	current_music = ""

func fade_in_music(duration: float):
	music_player.volume_db = -80
	var tween = create_tween()
	var target_db = get_music_target_db()
	tween.tween_property(music_player, "volume_db", target_db, duration)

func fade_out_music(duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, duration)

func get_music_target_db() -> float:
	return linear_to_db(music_volume * master_volume * volume_boost)

func get_sfx_target_db(volume_modifier: float = 1.0) -> float:
	return linear_to_db(sfx_volume * master_volume * volume_boost * volume_modifier)

func get_ui_target_db() -> float:
	return linear_to_db(ui_volume * master_volume * volume_boost)

func play_sfx(sound_name: String, pitch_variation: float = 0.0, volume_modifier: float = 1.0):
	if not sfx_sounds.has(sound_name):
		return
	
	var player = get_next_sfx_player()
	player.stream = sfx_sounds[sound_name]
	player.volume_db = get_sfx_target_db(volume_modifier)
	
	if pitch_variation > 0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0
	
	player.play()

# Alternative function for positional audio when you DO want distance effects
func play_sfx_at_position(sound_name: String, global_pos: Vector2, pitch_variation: float = 0.0, volume_modifier: float = 1.0):
	if not sfx_sounds.has(sound_name):
		return
	
	# Create a temporary AudioStreamPlayer2D for positional audio
	var temp_player = AudioStreamPlayer2D.new()
	get_tree().current_scene.add_child(temp_player)
	temp_player.global_position = global_pos
	temp_player.stream = sfx_sounds[sound_name]
	temp_player.volume_db = get_sfx_target_db(volume_modifier)
	
	if pitch_variation > 0:
		temp_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		temp_player.pitch_scale = 1.0
	
	temp_player.play()
	
	# Clean up the temporary player when done
	temp_player.finished.connect(func(): temp_player.queue_free())

func play_ui_sound(sound_name: String):
	if not ui_sounds.has(sound_name):
		return
	
	ui_player.stream = ui_sounds[sound_name]
	ui_player.volume_db = get_ui_target_db()
	ui_player.play()

func get_next_sfx_player() -> AudioStreamPlayer:
	var player = sfx_players[current_sfx_index]
	current_sfx_index = (current_sfx_index + 1) % sfx_players.size()
	return player

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	update_all_volumes()
	save_volume_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = get_music_target_db()
	save_volume_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	update_sfx_volume()
	save_volume_settings()

func set_ui_volume(volume: float):
	ui_volume = clamp(volume, 0.0, 1.0)
	ui_player.volume_db = get_ui_target_db()
	save_volume_settings()

func set_volume_boost(boost: float):
	volume_boost = clamp(boost, 0.1, 3.0)  # Allow boost from 0.1x to 3x
	update_all_volumes()
	save_volume_settings()

func update_all_volumes():
	music_player.volume_db = get_music_target_db()
	ui_player.volume_db = get_ui_target_db()
	update_sfx_volume()

func update_sfx_volume():
	var target_db = get_sfx_target_db()
	for player in sfx_players:
		if not player.playing:
			player.volume_db = target_db

func save_volume_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "volume_boost", volume_boost)
	config.save("user://audio_settings.cfg")

func load_volume_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		ui_volume = config.get_value("audio", "ui_volume", 1.0)
		volume_boost = config.get_value("audio", "volume_boost", 1.5)

func play_footstep():
	play_sfx("player_walk", 0.1, 0.3)

func play_enemy_death_random():
	play_sfx("enemy_death", 0.2)

# Updated explosion function - now you can choose between positional and non-positional
func play_explosion_at_position(global_pos: Vector2, use_positional: bool = true):
	if use_positional:
		var distance_to_player = global_pos.distance_to(get_player_position())
		var volume_falloff = 1.0 - clamp(distance_to_player / 1000.0, 0.0, 0.8)
		play_sfx_at_position("explosion", global_pos, 0.1, volume_falloff)
	else:
		play_sfx("explosion", 0.1)

func get_player_position() -> Vector2:
	var player = get_node_or_null("/root/Game/GameWorld/Player")
	if player:
		return player.global_position
	return Vector2.ZERO

func play_music_for_wave(wave_number: int):
	if wave_number <= 5:
		play_music("gameplay_intense")
	else:
		play_music("gameplay")

# Getter functions
func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_ui_volume() -> float:
	return ui_volume

func get_volume_boost() -> float:
	return volume_boost

# Debug function to test max volume
func test_max_volume():
	set_master_volume(1.0)
	set_music_volume(1.0)
	set_sfx_volume(1.0)
	set_ui_volume(1.0)
	set_volume_boost(2.0)  # 2x boost for testing
	play_sfx("player_shoot")
