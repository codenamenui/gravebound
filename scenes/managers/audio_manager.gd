extends Node

@onready var music_player: AudioStreamPlayer2D = $MusicPlayer
@onready var ui_player: AudioStreamPlayer2D = $UIPlayer
@onready var sfx_pool: Node = $SFXPool

var music_volume: float = 0.8
var sfx_volume: float = 0.8
var ui_volume: float = 0.8
var master_volume: float = 1.0

var current_music: String = ""
var music_tracks: Dictionary = {}
var sfx_sounds: Dictionary = {}
var ui_sounds: Dictionary = {}

var sfx_players: Array[AudioStreamPlayer2D] = []
var current_sfx_index: int = 0

func _ready():
	setup_sfx_pool()
	load_audio_resources()
	load_volume_settings()
	update_all_volumes()

func setup_sfx_pool():
	for i in range(8):
		var player = AudioStreamPlayer2D.new()
		player.name = "SFXPlayer" + str(i)
		sfx_pool.add_child(player)
		sfx_players.append(player)

func load_audio_resources():
	music_tracks = {
		#"menu": preload("res://audio/music/menu_music.ogg"),
		"gameplay": preload("res://audio/music/gameplay.mp3"),
		#"gameplay_intense": preload("res://audio/music/gameplay_intense.ogg"),
		#"perk_selection": preload("res://audio/music/perk_selection.ogg"),
		#"game_over": preload("res://audio/music/game_over.ogg")
	}
	
	sfx_sounds = {
		#"player_shoot": preload("res://audio/sfx/player_shoot.ogg"),
		#"player_hurt": preload("res://audio/sfx/player_hurt.ogg"),
		#"player_walk": preload("res://audio/sfx/player_walk.ogg"),
		#"enemy_death": preload("res://audio/sfx/enemy_death.ogg"),
		#"enemy_spawn": preload("res://audio/sfx/enemy_spawn.ogg"),
		#"pickup_collect": preload("res://audio/sfx/pickup_collect.ogg"),
		#"wave_complete": preload("res://audio/sfx/wave_complete.ogg"),
		#"wave_start": preload("res://audio/sfx/wave_start.ogg"),
		#"explosion": preload("res://audio/sfx/explosion.ogg"),
		#"perk_select": preload("res://audio/sfx/perk_select.ogg")
	}
	
	ui_sounds = {
		#"button_click": preload("res://audio/ui/button_click.ogg"),
		#"button_hover": preload("res://audio/ui/button_hover.ogg"),
		#"menu_open": preload("res://audio/ui/menu_open.ogg"),
		#"menu_close": preload("res://audio/ui/menu_close.ogg"),
		#"error": preload("res://audio/ui/error.ogg")
	}

func play_music(track_name: String, fade_duration: float = 1.0):
	if current_music == track_name:
		return
	
	if not music_tracks.has(track_name):
		print("Music track not found: " + track_name)
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
	var target_db = linear_to_db(music_volume * master_volume)
	tween.tween_property(music_player, "volume_db", target_db, duration)

func fade_out_music(duration: float):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, duration)

func play_sfx(sound_name: String, pitch_variation: float = 0.0, volume_modifier: float = 1.0):
	if not sfx_sounds.has(sound_name):
		print("SFX sound not found: " + sound_name)
		return
	
	var player = get_next_sfx_player()
	player.stream = sfx_sounds[sound_name]
	player.volume_db = linear_to_db(sfx_volume * master_volume * volume_modifier)
	
	if pitch_variation > 0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0
	
	player.play()

func play_ui_sound(sound_name: String):
	if not ui_sounds.has(sound_name):
		print("UI sound not found: " + sound_name)
		return
	
	ui_player.stream = ui_sounds[sound_name]
	ui_player.play()

func get_next_sfx_player() -> AudioStreamPlayer2D:
	var player = sfx_players[current_sfx_index]
	current_sfx_index = (current_sfx_index + 1) % sfx_players.size()
	return player

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	update_all_volumes()
	save_volume_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume * master_volume)
	save_volume_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	update_sfx_volume()
	save_volume_settings()

func set_ui_volume(volume: float):
	ui_volume = clamp(volume, 0.0, 1.0)
	ui_player.volume_db = linear_to_db(ui_volume * master_volume)
	save_volume_settings()

func update_all_volumes():
	music_player.volume_db = linear_to_db(music_volume * master_volume)
	ui_player.volume_db = linear_to_db(ui_volume * master_volume)
	update_sfx_volume()

func update_sfx_volume():
	for player in sfx_players:
		if not player.playing:
			player.volume_db = linear_to_db(sfx_volume * master_volume)

func save_volume_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.save("user://audio_settings.cfg")

func load_volume_settings():
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		ui_volume = config.get_value("audio", "ui_volume", 0.8)

func play_footstep():
	play_sfx("player_walk", 0.1, 0.3)

func play_enemy_death_random():
	play_sfx("enemy_death", 0.2)

func play_explosion_at_position(global_pos: Vector2):
	var distance_to_player = global_pos.distance_to(get_player_position())
	var volume_falloff = 1.0 - clamp(distance_to_player / 1000.0, 0.0, 0.8)
	play_sfx("explosion", 0.1, volume_falloff)

func get_player_position() -> Vector2:
	var player = get_node_or_null("/root/Game/GameWorld/Player")
	if player:
		return player.global_position
	return Vector2.ZERO

func play_music_for_wave(wave_number: int):
	if wave_number <= 5:
		play_music("gameplay")
	else:
		play_music("gameplay_intense")

func get_master_volume() -> float:
	return master_volume

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func get_ui_volume() -> float:
	return ui_volume
