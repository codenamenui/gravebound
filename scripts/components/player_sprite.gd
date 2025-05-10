extends Node2D
class_name CharacterSpriteComponent

var current_direction: Vector2 = Vector2(0, 1)
var current_animation: String = ""
var target_animation: String = ""

@export var attack_speed_scale: float = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var player = get_parent()

func set_direction(direction: Vector2):
	current_direction = direction

func play_idle():
	play_animation("idle")

func play_walk():
	play_animation("walk")

func play_hit():
	play_animation("hit", true)

func play_death():
	play_animation("death", true)

func get_direction_prefix():
	var x = current_direction.x
	var y = current_direction.y
	
	if abs(x) > 0.3 and abs(y) > 0.3:
		if x > 0:
			if y > 0:
				animated_sprite.flip_h = false
				return "bs"
			else:
				animated_sprite.flip_h = false
				return "ts"
		else:
			if y > 0:
				animated_sprite.flip_h = true
				return "bs"
			else:
				animated_sprite.flip_h = true
				return "ts"
	
	if abs(x) > abs(y):
		if x > 0:
			animated_sprite.flip_h = false
			return "s" 
		else:
			animated_sprite.flip_h = true
			return "s"
	else:
		if y > 0:
			return "f"
		else:
			return "b"

func play_animation(anim_name: String, speed_scale: float = 1.0, force_restart: bool = false):
	var dir_prefix = get_direction_prefix()
	var full_anim_name = dir_prefix + "_" + anim_name
	if current_animation == full_anim_name and !force_restart:
		return
		
	animated_sprite.speed_scale = speed_scale
	
	if animated_sprite.sprite_frames.has_animation(full_anim_name):
		current_animation = full_anim_name
		animated_sprite.play(full_anim_name)
		if anim_name == "attack":
			animated_sprite.speed_scale = attack_speed_scale
	else:
		var fallback = dir_prefix + "_idle"
		if animated_sprite.sprite_frames.has_animation(fallback):
			current_animation = fallback
			animated_sprite.play(fallback)
		else:
			current_animation = "f_idle"
			animated_sprite.play("f_idle")

func play_animation_frames(anim_name: String, start_frame: int, end_frame: int, speed: float = 1.0) -> void:
	var full_anim_name = get_direction_prefix() + "_" + anim_name
	
	if animated_sprite.sprite_frames.has_animation(full_anim_name):
		current_animation = full_anim_name
		animated_sprite.play(full_anim_name)
		animated_sprite.speed_scale = speed
		animated_sprite.frame = start_frame
	else:
		play_idle()

func update_animation_based_on_state():
	if player.is_attacking:
		return
	elif player.velocity.length() > 10:
		play_walk()
	else:
		play_idle()
