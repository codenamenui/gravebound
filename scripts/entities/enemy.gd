extends CharacterBody2D
class_name Enemy

@export var speed: float = 75.0
@export var knockback_force: float = 200.0
@export var knockback_decay: float = 800.0
@export var attack_range: float = 50.0  # This will only be used if no existing shape is found
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var initial_attack_delay: float = 1.5  # Delay before first attack
@export_category("Debug")
@export var show_detection_range: bool = true:
	set(value):
		show_detection_range = value
		if is_instance_valid(debug_draw):
			debug_draw.visible = value

var is_hit: bool = false
var is_dying: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var current_direction: Vector2 = Vector2.DOWN
var can_attack: bool = false
var player_ref: Player = null
var player_in_attack_range: bool = false
var initial_attack_timer: Timer

@onready var animated_sprite: AnimatedSprite2D = $CharacterSpriteComponent/AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: Node2D = $HealthBar
@onready var attack_timer: Timer = $AttackTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var debug_draw: EnemyDebugDraw

func _ready():
	health_component.health_depleted.connect(_on_health_depleted)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_timer.timeout.connect(_on_attack_cooldown_end)
	
	# Only set the attack shape if one doesn't already exist
	var attack_collision = attack_area.get_node("CollisionShape2D")
	if attack_collision and (attack_collision.shape == null):
		var attack_shape = CircleShape2D.new()
		attack_shape.radius = attack_range
		attack_collision.shape = attack_shape
	
	# Create initial attack timer
	initial_attack_timer = Timer.new()
	initial_attack_timer.one_shot = true
	initial_attack_timer.timeout.connect(_on_initial_attack_timer_timeout)
	add_child(initial_attack_timer)
	
	# Set up the debug draw node
	setup_debug_draw()
	
	# Speed up attack animations
	adjust_animation_speeds()
	
	play_idle()

func setup_debug_draw():
	# Remove any existing debug draw
	if has_node("DebugDraw"):
		remove_child(get_node("DebugDraw"))
		get_node("DebugDraw").queue_free()
	
	# Create a new debug draw node
	debug_draw = EnemyDebugDraw.new()
	debug_draw.name = "DebugDraw"
	debug_draw.visible = show_detection_range
	add_child(debug_draw)
	
	# Set references for drawing
	debug_draw.detection_area = detection_area
	debug_draw.attack_area = attack_area

func adjust_animation_speeds():
	# Double the speed of all attack animations
	var animations = animated_sprite.sprite_frames.get_animation_names()
	for anim_name in animations:
		if anim_name.ends_with("_attack"):
			var fps = animated_sprite.sprite_frames.get_animation_speed(anim_name)
			animated_sprite.sprite_frames.set_animation_speed(anim_name, fps * 2.0)

func _physics_process(delta):
	if is_dying:
		return

	if is_hit:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		
		if knockback_velocity.length() < 5:
			is_hit = false
			velocity = Vector2.ZERO
	else:
		if player_ref:
			current_direction = (player_ref.global_position - global_position).normalized()
			velocity = current_direction * speed
			
			# Only try to attack if player is in attack range AND cooldown is over
			if player_in_attack_range and can_attack:
				attack_player()
		else:
			velocity = Vector2.ZERO

	move_and_slide()
	update_animation()
	
	# Update debug visualization
	if is_instance_valid(debug_draw) and debug_draw.visible:
		debug_draw.queue_redraw()

func attack_player():
	if player_ref and can_attack and player_in_attack_range:
		# Start cooldown
		can_attack = false
		attack_timer.start(attack_cooldown)
		
		# Play attack animation first
		animated_sprite.play(get_direction_prefix() + "_attack")

func apply_attack_damage():
	# This function is called when the attack animation hits the point
	# where damage should be applied
	if player_ref:
		player_ref.take_damage()

func _on_attack_cooldown_end():
	can_attack = true
	# If player is still in range after cooldown, attack again
	if player_ref and player_in_attack_range:
		attack_player()

func _on_initial_attack_timer_timeout():
	# After the initial delay, allow attacking
	can_attack = true
	# If player is still in range after delay, attack now
	if player_ref and player_in_attack_range:
		attack_player()

func _on_detection_area_body_entered(body):
	if body is Player:
		player_ref = body
		# Reset can_attack to false and start delay timer
		can_attack = false
		initial_attack_timer.start(initial_attack_delay)

func _on_detection_area_body_exited(body):
	if body == player_ref:
		player_ref = null
		velocity = Vector2.ZERO
		# Cancel initial attack timer if player leaves detection range
		initial_attack_timer.stop()

func _on_attack_area_body_entered(body):
	if body is Player:
		player_in_attack_range = true
		# Don't immediately attack, wait for initial delay or cooldown

func _on_attack_area_body_exited(body):
	if body is Player:
		player_in_attack_range = false

func update_animation():
	if is_dying:
		return
	elif is_hit:
		play_hit()
	elif animated_sprite.animation.ends_with("_attack"):
		# Don't interrupt attack animation
		pass
	elif player_ref and velocity.length() > 0.1:
		play_walk()
	else:
		play_idle()

func take_damage(damage: int, from_direction: Vector2):
	if is_dying:
		return

	is_hit = true
	current_direction = normalize_to_diagonal(-from_direction)
	knockback_velocity = from_direction.normalized() * knockback_force
	play_hit()
	health_component.take_damage(damage)
	
	# If health is depleted after taking damage, ensure we handle death properly
	if health_component.current_health <= 0 and !is_dying:
		_on_health_depleted()

func _on_health_depleted():
	# Ensure we only start dying once
	if is_dying:
		return
		
	is_dying = true
	velocity = Vector2.ZERO
	
	# Disable collision to prevent further interactions
	set_collision_layer(0)
	
	# Disable all areas to prevent further detection/attacks
	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)
	attack_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitorable", false)
	
	play_death()

func _on_animation_finished():
	if is_dying and animated_sprite.animation.ends_with("_death"):
		# Ensure we're removed from the scene
		queue_free()
	elif is_hit and animated_sprite.animation.ends_with("_hit"):
		is_hit = false
		if is_dying:
			play_death()  # Make sure we continue with death if needed
		else:
			play_idle()
	elif animated_sprite.animation.ends_with("_attack"):
		# Apply damage at the end of attack animation
		apply_attack_damage()
		play_idle()

func play_idle():
	if not is_dying and not is_hit:
		animated_sprite.play(get_direction_prefix() + "_idle")

func play_walk():
	if not is_dying and not is_hit:
		animated_sprite.play(get_direction_prefix() + "_walk")

func play_hit():
	animated_sprite.play(get_direction_prefix() + "_hit")

func play_death():
	animated_sprite.play(get_direction_prefix() + "_death")

func get_direction_prefix() -> String:
	var dir = normalize_to_diagonal(current_direction)
	
	if dir.x > 0.7 and dir.y > 0.7:
		animated_sprite.flip_h = false
		return "bs"
	elif dir.x > 0.7 and dir.y < -0.7:
		animated_sprite.flip_h = false
		return "ts"
	elif dir.x < -0.7 and dir.y > 0.7:
		animated_sprite.flip_h = true
		return "bs"
	elif dir.x < -0.7 and dir.y < -0.7:
		animated_sprite.flip_h = true
		return "ts"
	elif abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			animated_sprite.flip_h = false
			return "s"
		else:
			animated_sprite.flip_h = true
			return "s"
	else:
		if dir.y > 0:
			return "f"
		else:
			return "b"

func normalize_to_diagonal(direction: Vector2) -> Vector2:
	var normalized = direction.normalized()
	var angle = normalized.angle()
	var snapped_angle = round(angle / (PI/4)) * (PI/4)
	return Vector2(cos(snapped_angle), sin(snapped_angle))

# Toggle debug visualization
func set_debug_visualization(enabled: bool):
	show_detection_range = enabled
