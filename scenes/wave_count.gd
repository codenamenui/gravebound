extends Control

class_name WaveStartDisplay

@export var display_duration: float = 3.0
@export var fade_in_time: float = 0.5
@export var fade_out_time: float = 0.5

@export var wave_text_format: String = "WAVE {wave_number}"
@export var ready_text: String = "GET READY!"
@export var final_wave_text: String = "FINAL WAVE!"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var wave_label: Label = $MainContainer/WaveLabel
@onready var sub_label: Label = $MainContainer/SubLabel

var current_wave: int = 0
var is_displaying: bool = false
var countdown_timer: float = 0.0
var wave_spawner: WaveEnemySpawner

func _ready():
	setup_animations()
	hide()
	find_wave_spawner()

func setup_animations():
	if not animation_player:
		return
		
	var library = AnimationLibrary.new()
	
	# Fade In Animation
	var fade_in_anim = Animation.new()
	fade_in_anim.length = fade_in_time
	
	var modulate_track = fade_in_anim.add_track(Animation.TYPE_VALUE)
	fade_in_anim.track_set_path(modulate_track, NodePath(".:modulate"))
	fade_in_anim.track_insert_key(modulate_track, 0.0, Color.TRANSPARENT)
	fade_in_anim.track_insert_key(modulate_track, fade_in_time, Color.WHITE)
	
	library.add_animation("fade_in", fade_in_anim)
	
	# Fade Out Animation
	var fade_out_anim = Animation.new()
	fade_out_anim.length = fade_out_time
	
	var fade_out_track = fade_out_anim.add_track(Animation.TYPE_VALUE)
	fade_out_anim.track_set_path(fade_out_track, NodePath(".:modulate"))
	fade_out_anim.track_insert_key(fade_out_track, 0.0, Color.WHITE)
	fade_out_anim.track_insert_key(fade_out_track, fade_out_time, Color.TRANSPARENT)
	
	library.add_animation("fade_out", fade_out_anim)
	
	animation_player.add_animation_library("default", library)
	animation_player.animation_finished.connect(_on_animation_finished)

func find_wave_spawner():
	wave_spawner = get_node_or_null("../WaveEnemySpawner")
	if not wave_spawner:
		wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	
	if wave_spawner:
		if not wave_spawner.wave_started.is_connected(_on_wave_started):
			wave_spawner.wave_started.connect(_on_wave_started)

func _on_wave_started(wave_number: int):
	show_wave_start(wave_number)

func show_wave_start(wave_number: int):
	if is_displaying:
		return
	
	current_wave = wave_number
	is_displaying = true
	countdown_timer = display_duration
	
	update_wave_text(wave_number)
	
	show()
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")

func update_wave_text(wave_number: int):
	var wave_text = wave_text_format.format({"wave_number": wave_number})
	
	# Check if final wave
	if wave_spawner and wave_spawner.has_property("total_waves") and wave_spawner.has_property("infinite_waves"):
		if not wave_spawner.infinite_waves and wave_number >= wave_spawner.total_waves:
			wave_text = final_wave_text
	
	wave_label.text = wave_text
	sub_label.text = ready_text

func hide_display():
	if not is_displaying:
		return
	
	is_displaying = false
	
	if animation_player and animation_player.has_animation("fade_out"):
		animation_player.play("fade_out")
	else:
		hide()

func _process(delta):
	if not is_displaying:
		return
	
	countdown_timer -= delta
	
	if countdown_timer <= 0:
		hide_display()

func _on_animation_finished(anim_name: String):
	if anim_name == "fade_out":
		hide()

# Public API
func set_wave_spawner(spawner: WaveEnemySpawner):
	if wave_spawner and wave_spawner.wave_started.is_connected(_on_wave_started):
		wave_spawner.wave_started.disconnect(_on_wave_started)
	
	wave_spawner = spawner
	if wave_spawner:
		wave_spawner.wave_started.connect(_on_wave_started)

func show_custom_message(title: String, subtitle: String, duration: float = 3.0):
	if is_displaying:
		return
	
	is_displaying = true
	countdown_timer = duration
	
	wave_label.text = title
	sub_label.text = subtitle
	
	show()
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")

func force_hide():
	is_displaying = false
	hide()
	if animation_player:
		animation_player.stop()
