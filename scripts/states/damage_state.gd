class_name DamageState
extends State

@export var knockback_decay: float = 0.85
@export var hit_flash_count: int = 3
@export var hit_flash_interval: float = 0.08
@export var invincibility_duration: float = 0.5

var knockback_velocity: Vector2 = Vector2.ZERO
var original_modulate: Color

func enter(msg: Dictionary = {}):
	if msg.has("knockback"):
		knockback_velocity = msg["knockback"]
	
	original_modulate = enemy.modulate
	play_hit_effects()
	
	if enemy.health_component:
		enemy.health_component.set_invincible(true)
		await get_tree().create_timer(invincibility_duration).timeout
		enemy.health_component.set_invincible(false)
	
	# Only transition if knockback is complete
	if knockback_velocity.length() <= 5.0:
		transition_requested.emit("ChaseState")

func physics_update(delta: float):
	if knockback_velocity.length() > 5.0:
		enemy.velocity = knockback_velocity
		print(enemy.velocity)
		knockback_velocity *= knockback_decay
		enemy.move_and_slide()
	else:
		knockback_velocity = Vector2.ZERO
		transition_requested.emit("ChaseState")

func play_hit_effects():
	# Multi-flash effect
	for i in hit_flash_count:
		enemy.modulate = Color(5, 5, 5)  # White flash
		await get_tree().create_timer(hit_flash_interval).timeout
		enemy.modulate = original_modulate
		await get_tree().create_timer(hit_flash_interval).timeout
	
	# Shake health bar
	if enemy.health_bar:
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(enemy.health_bar, "position:x", 4.0, 0.05)
		tween.tween_property(enemy.health_bar, "position:x", -4.0, 0.1)
		tween.tween_property(enemy.health_bar, "position:x", 0.0, 0.05)

func exit():
	enemy.modulate = original_modulate
	knockback_velocity = Vector2.ZERO
