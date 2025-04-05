extends Node2D

var current_direction: Vector2 = Vector2(0, 1)
var current_animation: String = ""

@export var attack_speed_scale: float = 3.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var player: Player = get_parent()

func set_direction(direction: Vector2):
	current_direction = direction

func play_idle():
	var anim_prefix = get_direction_prefix()
	play_animation(anim_prefix + "_idle")

func play_walk():
	var anim_prefix = get_direction_prefix()
	play_animation(anim_prefix + "_walk")

func play_attack():
	var anim_prefix = get_direction_prefix()
	play_animation(anim_prefix + "_attack", true)

func play_hit():
	var anim_prefix = get_direction_prefix()
	play_animation(anim_prefix + "_hit")

func play_death():
	var anim_prefix = get_direction_prefix()
	play_animation(anim_prefix + "_death")

func get_direction_prefix():
	var x = current_direction.x
	var y = current_direction.y
	
	if abs(x) > 0.3 and abs(y) > 0.3:
		if x > 0:
			if y > 0:
				return "bs"
			else:
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

func play_animation(anim_name, is_attack: bool = false):
	current_animation = anim_name
	
	animated_sprite.speed_scale = 1.0
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		if is_attack:
			animated_sprite.speed_scale = attack_speed_scale
	else:
		var fallback = anim_name.split("_")[0] + "_idle"
		if animated_sprite.sprite_frames.has_animation(fallback):
			current_animation = fallback
			animated_sprite.play(fallback)
		else:
			current_animation = "f_idle"
			animated_sprite.play("f_idle")

func _on_animation_finished():
	if current_animation.ends_with("_attack"):
		player.on_attack_animation_finished()
	elif current_animation.ends_with("_hit"):
		player.on_hit_animation_finished()
	elif current_animation.ends_with("_death"):
		player.on_death_animation_finished()
