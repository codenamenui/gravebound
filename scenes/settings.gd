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

# Mobile-Specific Controls
@onready var touch_sensitivity_slider: HSlider = $VBoxContainer/ControlsSection/TouchSensitivityContainer/TouchSensitivitySlider
@onready var touch_sensitivity_label: Label = $VBoxContainer/ControlsSection/TouchSensitivityContainer/TouchSensitivityLabel
@onready var joystick_size_slider: HSlider = $VBoxContainer/ControlsSection/JoystickSizeContainer/JoystickSizeSlider
@onready var joystick_size_label: Label = $VBoxContainer/ControlsSection/JoystickSizeContainer/JoystickSizeLabel
@onready var haptic_feedback_button: CheckBox = $VBoxContainer/ControlsSection/HapticFeedbackContainer/HapticFeedbackCheckBox
@onready var touch_indicators_button: CheckBox = $VBoxContainer/ControlsSection/TouchIndicatorsContainer/TouchIndicatorsCheckBox

# Performance Settings
@onready var graphics_quality_option: OptionButton = $VBoxContainer/PerformanceSection/GraphicsQualityContainer/GraphicsQualityOption
@onready var particle_density_slider: HSlider = $VBoxContainer/PerformanceSection/ParticleDensityContainer/ParticleDensitySlider
@onready var particle_density_label: Label = $VBoxContainer/PerformanceSection/ParticleDensityContainer/ParticleDensityLabel
@onready var battery_saver_button: CheckBox = $VBoxContainer/PerformanceSection/BatterySaverContainer/BatterySaverCheckBox
@onready var auto_quality_button: CheckBox = $VBoxContainer/PerformanceSection/AutoQualityContainer/AutoQualityCheckBox

# Gameplay Settings
@onready var auto_pause_button: CheckBox = $VBoxContainer/GameplaySection/AutoPauseContainer/AutoPauseCheckBox
@onready var screen_shake_button: CheckBox = $VBoxContainer/GameplaySection/ScreenShakeContainer/ScreenShakeCheckBox
@onready var damage_numbers_button: CheckBox = $VBoxContainer/GameplaySection/DamageNumbersContainer/DamageNumbersCheckBox
@onready var auto_aim_assist_button: CheckBox = $VBoxContainer/GameplaySection/AutoAimAssistContainer/AutoAimAssistCheckBox

# UI Settings
@onready var ui_scale_slider: HSlider = $VBoxContainer/UISection/UIScaleContainer/UIScaleSlider
@onready var ui_scale_label: Label = $VBoxContainer/UISection/UIScaleContainer/UIScaleLabel
@onready var button_opacity_slider: HSlider = $VBoxContainer/UISection/ButtonOpacityContainer/ButtonOpacitySlider
@onready var button_opacity_label: Label = $VBoxContainer/UISection/ButtonOpacityContainer/ButtonOpacityLabel
@onready var show_fps_button: CheckBox = $VBoxContainer/UISection/ShowFPSContainer/ShowFPSCheckBox

# Control Buttons
@onready var reset_button: Button = $VBoxContainer/ButtonsContainer/ResetButton
@onready var apply_button: Button = $VBoxContainer/ButtonsContainer/ApplyButton
@onready var back_button: Button = $VBoxContainer/ButtonsContainer/BackButton

# Settings storage
var settings_config: ConfigFile
var settings_file_path: String = "user://mobile_settings.cfg"

# Default values
var default_settings = {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"ui_volume": 0.8
	},
	"controls": {
		"touch_sensitivity": 1.0,
		"joystick_size": 1.0,
		"haptic_feedback": true,
		"touch_indicators": true
	},
	"performance": {
		"graphics_quality": 1, # 0=Low, 1=Medium, 2=High
		"particle_density": 1.0,
		"battery_saver": false,
		"auto_quality": true
	},
	"gameplay": {
		"auto_pause_on_focus_lost": true,
		"screen_shake_enabled": true,
		"damage_numbers_enabled": true,
		"auto_aim_assist": false
	},
	"ui": {
		"ui_scale": 1.0,
		"button_opacity": 0.8,
		"show_fps": false
	}
}

func _ready():
	settings_config = ConfigFile.new()
	setup_mobile_ui_elements()
	load_settings()
	connect_signals()
	apply_settings()

func setup_mobile_ui_elements():
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
	
	# Setup touch controls
	touch_sensitivity_slider.min_value = 0.5
	touch_sensitivity_slider.max_value = 3.0
	touch_sensitivity_slider.step = 0.1
	
	joystick_size_slider.min_value = 0.5
	joystick_size_slider.max_value = 1.5
	joystick_size_slider.step = 0.1
	
	# Setup performance controls
	graphics_quality_option.add_item("Low (Battery Saving)")
	graphics_quality_option.add_item("Medium (Recommended)")
	graphics_quality_option.add_item("High (Best Quality)")
	
	particle_density_slider.min_value = 0.25
	particle_density_slider.max_value = 1.0
	particle_density_slider.step = 0.25
	
	# Setup UI controls
	ui_scale_slider.min_value = 0.8
	ui_scale_slider.max_value = 1.4
	ui_scale_slider.step = 0.1
	
	button_opacity_slider.min_value = 0.3
	button_opacity_slider.max_value = 1.0
	button_opacity_slider.step = 0.1

func connect_signals():
	# Volume sliders
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	ui_volume_slider.value_changed.connect(_on_ui_volume_changed)
	
	# Touch controls
	touch_sensitivity_slider.value_changed.connect(_on_touch_sensitivity_changed)
	joystick_size_slider.value_changed.connect(_on_joystick_size_changed)
	haptic_feedback_button.toggled.connect(_on_haptic_feedback_toggled)
	touch_indicators_button.toggled.connect(_on_touch_indicators_toggled)
	
	# Performance settings
	graphics_quality_option.item_selected.connect(_on_graphics_quality_selected)
	particle_density_slider.value_changed.connect(_on_particle_density_changed)
	battery_saver_button.toggled.connect(_on_battery_saver_toggled)
	auto_quality_button.toggled.connect(_on_auto_quality_toggled)
	
	# Gameplay settings
	auto_pause_button.toggled.connect(_on_auto_pause_toggled)
	screen_shake_button.toggled.connect(_on_screen_shake_toggled)
	damage_numbers_button.toggled.connect(_on_damage_numbers_toggled)
	auto_aim_assist_button.toggled.connect(_on_auto_aim_assist_toggled)
	
	# UI settings
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	button_opacity_slider.value_changed.connect(_on_button_opacity_changed)
	show_fps_button.toggled.connect(_on_show_fps_toggled)
	
	# Control buttons
	reset_button.pressed.connect(_on_reset_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)

func load_settings():
	if settings_config.load(settings_file_path) != OK:
		save_default_settings()
		return
	
	# Load audio settings
	master_volume_slider.value = settings_config.get_value("audio", "master_volume", default_settings.audio.master_volume)
	music_volume_slider.value = settings_config.get_value("audio", "music_volume", default_settings.audio.music_volume)
	sfx_volume_slider.value = settings_config.get_value("audio", "sfx_volume", default_settings.audio.sfx_volume)
	ui_volume_slider.value = settings_config.get_value("audio", "ui_volume", default_settings.audio.ui_volume)
	
	# Load control settings
	touch_sensitivity_slider.value = settings_config.get_value("controls", "touch_sensitivity", default_settings.controls.touch_sensitivity)
	joystick_size_slider.value = settings_config.get_value("controls", "joystick_size", default_settings.controls.joystick_size)
	haptic_feedback_button.button_pressed = settings_config.get_value("controls", "haptic_feedback", default_settings.controls.haptic_feedback)
	touch_indicators_button.button_pressed = settings_config.get_value("controls", "touch_indicators", default_settings.controls.touch_indicators)
	
	# Load performance settings
	graphics_quality_option.selected = settings_config.get_value("performance", "graphics_quality", default_settings.performance.graphics_quality)
	particle_density_slider.value = settings_config.get_value("performance", "particle_density", default_settings.performance.particle_density)
	battery_saver_button.button_pressed = settings_config.get_value("performance", "battery_saver", default_settings.performance.battery_saver)
	auto_quality_button.button_pressed = settings_config.get_value("performance", "auto_quality", default_settings.performance.auto_quality)
	
	# Load gameplay settings
	auto_pause_button.button_pressed = settings_config.get_value("gameplay", "auto_pause_on_focus_lost", default_settings.gameplay.auto_pause_on_focus_lost)
	screen_shake_button.button_pressed = settings_config.get_value("gameplay", "screen_shake_enabled", default_settings.gameplay.screen_shake_enabled)
	damage_numbers_button.button_pressed = settings_config.get_value("gameplay", "damage_numbers_enabled", default_settings.gameplay.damage_numbers_enabled)
	auto_aim_assist_button.button_pressed = settings_config.get_value("gameplay", "auto_aim_assist", default_settings.gameplay.auto_aim_assist)
	
	# Load UI settings
	ui_scale_slider.value = settings_config.get_value("ui", "ui_scale", default_settings.ui.ui_scale)
	button_opacity_slider.value = settings_config.get_value("ui", "button_opacity", default_settings.ui.button_opacity)
	show_fps_button.button_pressed = settings_config.get_value("ui", "show_fps", default_settings.ui.show_fps)
	
	update_all_labels()

func save_settings():
	# Save audio settings
	settings_config.set_value("audio", "master_volume", master_volume_slider.value)
	settings_config.set_value("audio", "music_volume", music_volume_slider.value)
	settings_config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	settings_config.set_value("audio", "ui_volume", ui_volume_slider.value)
	
	# Save control settings
	settings_config.set_value("controls", "touch_sensitivity", touch_sensitivity_slider.value)
	settings_config.set_value("controls", "joystick_size", joystick_size_slider.value)
	settings_config.set_value("controls", "haptic_feedback", haptic_feedback_button.button_pressed)
	settings_config.set_value("controls", "touch_indicators", touch_indicators_button.button_pressed)
	
	# Save performance settings
	settings_config.set_value("performance", "graphics_quality", graphics_quality_option.selected)
	settings_config.set_value("performance", "particle_density", particle_density_slider.value)
	settings_config.set_value("performance", "battery_saver", battery_saver_button.button_pressed)
	settings_config.set_value("performance", "auto_quality", auto_quality_button.button_pressed)
	
	# Save gameplay settings
	settings_config.set_value("gameplay", "auto_pause_on_focus_lost", auto_pause_button.button_pressed)
	settings_config.set_value("gameplay", "screen_shake_enabled", screen_shake_button.button_pressed)
	settings_config.set_value("gameplay", "damage_numbers_enabled", damage_numbers_button.button_pressed)
	settings_config.set_value("gameplay", "auto_aim_assist", auto_aim_assist_button.button_pressed)
	
	# Save UI settings
	settings_config.set_value("ui", "ui_scale", ui_scale_slider.value)
	settings_config.set_value("ui", "button_opacity", button_opacity_slider.value)
	settings_config.set_value("ui", "show_fps", show_fps_button.button_pressed)
	
	settings_config.save(settings_file_path)

func save_default_settings():
	for section in default_settings:
		for key in default_settings[section]:
			settings_config.set_value(section, key, default_settings[section][key])
	settings_config.save(settings_file_path)

func apply_settings():
	# Apply audio settings
	AudioManager.set_master_volume(master_volume_slider.value)
	AudioManager.set_music_volume(music_volume_slider.value)
	AudioManager.set_sfx_volume(sfx_volume_slider.value)
	AudioManager.set_ui_volume(ui_volume_slider.value)
	
	# Apply performance settings
	apply_graphics_quality(graphics_quality_option.selected)
	apply_battery_saver_mode(battery_saver_button.button_pressed)
	
	# Apply mobile-specific settings to GameData
	GameData.touch_sensitivity = touch_sensitivity_slider.value
	GameData.joystick_size = joystick_size_slider.value
	GameData.haptic_feedback_enabled = haptic_feedback_button.button_pressed
	GameData.touch_indicators_enabled = touch_indicators_button.button_pressed
	GameData.particle_density = particle_density_slider.value
	GameData.auto_pause_on_focus_lost = auto_pause_button.button_pressed
	GameData.screen_shake_enabled = screen_shake_button.button_pressed
	GameData.damage_numbers_enabled = damage_numbers_button.button_pressed
	GameData.auto_aim_assist = auto_aim_assist_button.button_pressed
	GameData.ui_scale = ui_scale_slider.value
	GameData.button_opacity = button_opacity_slider.value
	GameData.show_fps = show_fps_button.button_pressed

func apply_graphics_quality(quality_level: int):
	match quality_level:
		0: # Low
			Engine.max_fps = 30
			get_viewport().msaa_2d = Viewport.MSAA_DISABLED
		1: # Medium
			Engine.max_fps = 60
			get_viewport().msaa_2d = Viewport.MSAA_2X
		2: # High
			Engine.max_fps = 60
			get_viewport().msaa_2d = Viewport.MSAA_4X

func apply_battery_saver_mode(enabled: bool):
	if enabled:
		Engine.max_fps = 30
		# Reduce screen brightness if possible
		if DisplayServer.screen_get_dpi() > 0:
			# Platform-specific battery optimizations would go here
			pass
	else:
		var quality = graphics_quality_option.selected
		if quality == 1 or quality == 2:
			Engine.max_fps = 60

func update_all_labels():
	update_volume_labels()
	update_control_labels()
	update_performance_labels()
	update_ui_labels()

func update_volume_labels():
	master_volume_label.text = "Master: " + str(int(master_volume_slider.value * 100)) + "%"
	music_volume_label.text = "Music: " + str(int(music_volume_slider.value * 100)) + "%"
	sfx_volume_label.text = "SFX: " + str(int(sfx_volume_slider.value * 100)) + "%"
	ui_volume_label.text = "UI: " + str(int(ui_volume_slider.value * 100)) + "%"

func update_control_labels():
	touch_sensitivity_label.text = "Touch Sensitivity: " + str(touch_sensitivity_slider.value).pad_decimals(1) + "x"
	joystick_size_label.text = "Joystick Size: " + str(int(joystick_size_slider.value * 100)) + "%"

func update_performance_labels():
	particle_density_label.text = "Particles: " + str(int(particle_density_slider.value * 100)) + "%"

func update_ui_labels():
	ui_scale_label.text = "UI Scale: " + str(int(ui_scale_slider.value * 100)) + "%"
	button_opacity_label.text = "Button Opacity: " + str(int(button_opacity_slider.value * 100)) + "%"

# Signal handlers
func _on_master_volume_changed(value: float):
	AudioManager.set_master_volume(value)
	update_volume_labels()

func _on_music_volume_changed(value: float):
	AudioManager.set_music_volume(value)
	update_volume_labels()

func _on_sfx_volume_changed(value: float):
	AudioManager.set_sfx_volume(value)
	update_volume_labels()

func _on_ui_volume_changed(value: float):
	AudioManager.set_ui_volume(value)
	update_volume_labels()

func _on_touch_sensitivity_changed(value: float):
	GameData.touch_sensitivity = value
	update_control_labels()

func _on_joystick_size_changed(value: float):
	GameData.joystick_size = value
	update_control_labels()

func _on_haptic_feedback_toggled(pressed: bool):
	GameData.haptic_feedback_enabled = pressed
	if pressed:
		# Test vibration
		Input.vibrate_handheld(100)

func _on_touch_indicators_toggled(pressed: bool):
	GameData.touch_indicators_enabled = pressed

func _on_graphics_quality_selected(index: int):
	apply_graphics_quality(index)

func _on_particle_density_changed(value: float):
	GameData.particle_density = value
	update_performance_labels()

func _on_battery_saver_toggled(pressed: bool):
	apply_battery_saver_mode(pressed)

func _on_auto_quality_toggled(pressed: bool):
	GameData.auto_quality_adjustment = pressed

func _on_auto_pause_toggled(pressed: bool):
	GameData.auto_pause_on_focus_lost = pressed

func _on_screen_shake_toggled(pressed: bool):
	GameData.screen_shake_enabled = pressed

func _on_damage_numbers_toggled(pressed: bool):
	GameData.damage_numbers_enabled = pressed

func _on_auto_aim_assist_toggled(pressed: bool):
	GameData.auto_aim_assist = pressed

func _on_ui_scale_changed(value: float):
	GameData.ui_scale = value
	update_ui_labels()

func _on_button_opacity_changed(value: float):
	GameData.button_opacity = value
	update_ui_labels()

func _on_show_fps_toggled(pressed: bool):
	GameData.show_fps = pressed

func _on_reset_pressed():
	# Reset all settings to defaults
	master_volume_slider.value = default_settings.audio.master_volume
	music_volume_slider.value = default_settings.audio.music_volume
	sfx_volume_slider.value = default_settings.audio.sfx_volume
	ui_volume_slider.value = default_settings.audio.ui_volume
	
	touch_sensitivity_slider.value = default_settings.controls.touch_sensitivity
	joystick_size_slider.value = default_settings.controls.joystick_size
	haptic_feedback_button.button_pressed = default_settings.controls.haptic_feedback
	touch_indicators_button.button_pressed = default_settings.controls.touch_indicators
	
	graphics_quality_option.selected = default_settings.performance.graphics_quality
	particle_density_slider.value = default_settings.performance.particle_density
	battery_saver_button.button_pressed = default_settings.performance.battery_saver
	auto_quality_button.button_pressed = default_settings.performance.auto_quality
	
	auto_pause_button.button_pressed = default_settings.gameplay.auto_pause_on_focus_lost
	screen_shake_button.button_pressed = default_settings.gameplay.screen_shake_enabled
	damage_numbers_button.button_pressed = default_settings.gameplay.damage_numbers_enabled
	auto_aim_assist_button.button_pressed = default_settings.gameplay.auto_aim_assist
	
	ui_scale_slider.value = default_settings.ui.ui_scale
	button_opacity_slider.value = default_settings.ui.button_opacity
	show_fps_button.button_pressed = default_settings.ui.show_fps
	
	update_all_labels()

func _on_apply_pressed():
	apply_settings()
	save_settings()
	print("Mobile settings applied and saved!")

func _on_back_pressed():
	if SceneManager:
		SceneManager.transition_to_state(GameData.GameState.MAIN_MENU)
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# Public functions
func get_setting(section: String, key: String, default_value = null):
	return settings_config.get_value(section, key, default_value)

func set_setting(section: String, key: String, value):
	settings_config.set_value(section, key, value)
	settings_config.save(settings_file_path)
