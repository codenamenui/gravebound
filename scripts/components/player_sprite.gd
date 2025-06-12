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

func get_direction():
	var x = current_direction.x
	var y = current_direction.y
	
	if x > 0:
		animated_sprite.flip_h = false  # Face right
	elif x < 0:
		animated_sprite.flip_h = true   # Face left
		
func play_animation(anim_name: String, speed_scale: float = 1.0, force_restart: bool = false):
	get_direction()
	var full_anim_name = anim_name
	if current_animation == full_anim_name and !force_restart:
		return
		
	animated_sprite.speed_scale = speed_scale
	
	current_animation = full_anim_name
	animated_sprite.play(full_anim_name)

	if anim_name == "attack":
		animated_sprite.speed_scale = attack_speed_scale
