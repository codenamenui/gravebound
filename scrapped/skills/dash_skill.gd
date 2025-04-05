extends BaseSkill
class_name DashSkill

# Dash-specific properties
@export var dash_distance: float = 200.0
@export var dash_speed: float = 800.0
@export var dash_invulnerability: bool = true
@export var dash_damage: float = 0.0  # Set to 0 for non-damaging dash
@export var dash_trail_scene: PackedScene

var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_start_position: Vector2 = Vector2.ZERO
var dash_target_position: Vector2 = Vector2.ZERO
var original_collision_mask: int = 0

func _init():
	skill_name = "Quick Dash"
	description = "Quickly dash in a direction, avoiding damage while dashing"
	cooldown_time = 3.0
	execution_time = 0.2
	recovery_time = 0.1
	speed_multiplier = 0.0  # Not used for dash
	animation_name = "dash"
	base_damage = 0.0
	hitbox_duration = 0.2
	hitbox_offset = 0.0

func execute(direction: Vector2) -> bool:
	if is_on_cooldown or is_executing:
		return false
	
	# Store dash properties
	dash_direction = direction.normalized()
	dash_start_position = owner_node.global_position
	dash_target_position = dash_start_position + (dash_direction * dash_distance)
	
	# Mark as executing to prevent other skills
	is_executing = true
	is_dashing = true
	
	# Save original collision mask for restoration later
	if owner_node is CollisionObject2D:
		original_collision_mask = owner_node.collision_mask
	
	# Start the dash process
	_start_dash()
	
	# Start timers
	execution_timer.start(execution_time)
	cooldown_timer.start(cooldown_time)
	
	emit_signal("skill_started")
	return true

func _apply_skill_effects() -> void:
	# Play animation if available
	if owner_node.has_method("play_animation"):
		owner_node.play_animation(animation_name)
	
	# Make invulnerable during dash if specified
	if dash_invulnerability and owner_node.has_method("start_invulnerability"):
		owner_node.start_invulnerability()
	elif dash_invulnerability and owner_node is CollisionObject2D:
		# Temporarily disable collision with enemies
		owner_node.collision_mask = owner_node.collision_mask & ~(1 << 2)  # Assuming enemies are on layer 2
	
	# Spawn dash trail if specified
	if dash_trail_scene != null:
		var trail = dash_trail_scene.instantiate()
		owner_node.get_parent().add_child(trail)
		trail.global_position = owner_node.global_position
		trail.rotation = dash_direction.angle()
		# Trail should clean itself up after animation

# Start the dash movement
func _start_dash() -> void:
	# Connect to the physics process to handle the dash movement
	if not owner_node.is_connected("physics_process", _dash_physics_process):
		owner_node.connect("physics_process", _dash_physics_process)
	
	# If this is a damaging dash, spawn a hitbox
	if dash_damage > 0 and hitbox_scene != null:
		_spawn_hitbox()

# Physics process handling for the dash movement
func _dash_physics_process(delta: float) -> void:
	if not is_dashing:
		return
	
	# Calculate the dash movement
	var move_distance = dash_speed * delta
	var distance_to_target = owner_node.global_position.distance_to(dash_target_position)
	
	# Handle reaching the target
	if move_distance >= distance_to_target:
		owner_node.global_position = dash_target_position
		_end_dash()
		return
	
	# Move towards the target
	var movement = dash_direction * move_distance
	
	# Apply movement directly if owner is a CharacterBody2D
	if owner_node is CharacterBody2D:
		owner_node.velocity = dash_direction * dash_speed
		owner_node.move_and_slide()
	else:
		# Otherwise just move the position
		owner_node.global_position += movement

# End the dash
func _end_dash() -> void:
	is_dashing = false
	
	# Disconnect the physics process
	if owner_node.is_connected("physics_process", _dash_physics_process):
		owner_node.disconnect("physics_process", _dash_physics_process)
	
	# Stop movement if owner is a CharacterBody2D
	if owner_node is CharacterBody2D:
		owner_node.velocity = Vector2.ZERO
	
	# Restore collision mask if we changed it
	if dash_invulnerability and owner_node is CollisionObject2D:
		owner_node.collision_mask = original_collision_mask
	
	# Start recovery phase
	recovery_timer.start(recovery_time)

func _on_execution_timeout() -> void:
	super._on_execution_timeout()
	
	# End dash if it's still active when execution timer ends
	if is_dashing:
		_end_dash()

func _apply_level_modifiers() -> void:
	# Improve dash parameters based on level
	dash_distance = 200.0 * (1 + (current_level - 1) * 0.2)
	dash_speed = 800.0 * (1 + (current_level - 1) * 0.1)
	cooldown_time = max(1.5, 3.0 - (current_level - 1) * 0.3)
	
	# Add damage at higher levels
	if current_level >= 3:
		dash_damage = 5.0 * (current_level - 2)
		base_damage = dash_damage
	else:
		dash_damage = 0.0
		base_damage = 0.0
