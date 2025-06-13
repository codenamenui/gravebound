extends Control

# Volume Controls
@onready var master_volume_slider: HSlider = $VBoxContainer/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_label: Label = $VBoxContainer/AudioSection/MasterVolumeContainer/MasterVolumeLabel
@onready var music_volume_slider: HSlider = $VBoxContainer/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_label: Label = $VBoxContainer/AudioSection/MusicVolumeContainer/MusicVolumeLabel
@onready var sfx_volume_slider: HSlider = $VBoxContainer/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_label: Label = $VBoxContainer/AudioSection/SFXVolumeContainer/SFXVolumeLabel
@onready var ui_volume_slider: HSlider = $VBoxContainer/AudioSection/UIVolumeContainer/UIVolumeSlider
@onready var ui_volume_label: Label = $VBoxContainer/AudioSection/UIVolumeContainer/UIVolumeLabel

# Control Button
@onready var back_button: Button = $VBoxContainer/ButtonsContainer/BackButton

# Settings storage
var settings_config: ConfigFile
var settings_file_path: String = "user://audio_settings.cfg"

# Default audio values
var default_audio_settings = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"ui_volume": 0.8
}

func _ready():
	settings_config = ConfigFile.new()
	setup_audio_sliders()
	load_settings()
	connect_signals()
	apply_audio_settings()

func setup_audio_sliders():
	# Setup volume sliders
	master_volume_slider.min_value = 0.0
	master_volume_slider.max_value = 1.0
	master_volume_slider.step = 0.01
	
	music_volume_slider.min_value = 0.0
	music_volume_slider.max_value = 1.0
	music_volume_slider.step = 0.01
	
	sfx_volume_slider.min_value = 0.0
	sfx_volume_slider.max_value = 1.0
	sfx_volume_slider.step = 0.01
	
	ui_volume_slider.min_value = 0.0
	ui_volume_slider.max_value = 1.0
	ui_volume_slider.step = 0.01

func connect_signals():
	# Volume sliders - connect to both update audio and save settings
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	ui_volume_slider.value_changed.connect(_on_ui_volume_changed)
	
	# Back button
	back_button.pressed.connect(_on_back_pressed)

func load_settings():
	if settings_config.load(settings_file_path) != OK:
		save_default_settings()
		return
	
	# Load audio settings
	master_volume_slider.value = settings_config.get_value("audio", "master_volume", default_audio_settings.master_volume)
	music_volume_slider.value = settings_config.get_value("audio", "music_volume", default_audio_settings.music_volume)
	sfx_volume_slider.value = settings_config.get_value("audio", "sfx_volume", default_audio_settings.sfx_volume)
	ui_volume_slider.value = settings_config.get_value("audio", "ui_volume", default_audio_settings.ui_volume)
	
	update_volume_labels()

func save_audio_settings():
	# Save audio settings immediately
	settings_config.set_value("audio", "master_volume", master_volume_slider.value)
	settings_config.set_value("audio", "music_volume", music_volume_slider.value)
	settings_config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	settings_config.set_value("audio", "ui_volume", ui_volume_slider.value)
	
	settings_config.save(settings_file_path)

func save_default_settings():
	for key in default_audio_settings:
		settings_config.set_value("audio", key, default_audio_settings[key])
	settings_config.save(settings_file_path)

func apply_audio_settings():
	# Apply audio settings to AudioManager
	AudioManager.set_master_volume(master_volume_slider.value)
	AudioManager.set_music_volume(music_volume_slider.value)
	AudioManager.set_sfx_volume(sfx_volume_slider.value)
	AudioManager.set_ui_volume(ui_volume_slider.value)

func update_volume_labels():
	master_volume_label.text = "Master: " + str(int(master_volume_slider.value * 100)) + "%"
	music_volume_label.text = "Music: " + str(int(music_volume_slider.value * 100)) + "%"
	sfx_volume_label.text = "SFX: " + str(int(sfx_volume_slider.value * 100)) + "%"
	ui_volume_label.text = "UI: " + str(int(ui_volume_slider.value * 100)) + "%"

# Signal handlers - each one updates audio, labels, and saves immediately
func _on_master_volume_changed(value: float):
	AudioManager.set_master_volume(value)
	update_volume_labels()
	save_audio_settings()

func _on_music_volume_changed(value: float):
	AudioManager.set_music_volume(value)
	update_volume_labels()
	save_audio_settings()

func _on_sfx_volume_changed(value: float):
	AudioManager.set_sfx_volume(value)
	update_volume_labels()
	save_audio_settings()

func _on_ui_volume_changed(value: float):
	AudioManager.set_ui_volume(value)
	update_volume_labels()
	save_audio_settings()

func _on_back_pressed():
	if GameData.from_game:
		GameData.from_game = false
		SceneManager.transition_to_state(GameData.GameState.PLAYING)
	else:
		SceneManager.transition_to_state(GameData.GameState.MAIN_MENU)

# Public functions for external access
func get_audio_setting(key: String, default_value = null):
	return settings_config.get_value("audio", key, default_value)

func set_audio_setting(key: String, value):
	settings_config.set_value("audio", key, value)
	settings_config.save(settings_file_path)
