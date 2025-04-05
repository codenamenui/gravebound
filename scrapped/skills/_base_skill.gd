extends Resource
class_name BaseSkill

# Basic skill properties
@export var skill_name: String = "Unnamed Skill"
@export var icon: Texture2D
@export var description: String = ""
@export var cooldown_time: float = 1.0
@export var execution_time: float = 0.3
@export var recovery_time: float = 0.2
@export var speed_multiplier: float = 0.5
@export var animation_name: String = "attack"

# Hitbox properties
@export var hitbox_scene: PackedScene
@export var hitbox_duration: float = 0.2
@export var hitbox_delay: float = 0.1  # Delay before hitbox appears
@export var hitbox_offset: float = 30.0

# Sound and visual effects
@export var skill_sfx: AudioStream
@export var skill_vfx_scene: PackedScene

# Stats
@export var base_damage: float = 10.0
@export var knockback_force: float = 100.0

# Skill state
var is_on_cooldown: bool = false
var is_executing: bool = false
var current_level: int = 1
var max_level: int = 5
var owner_node: Node = null
var last_use_direction: Vector2 = Vector2.ZERO

# Timers
var cooldown_timer: Timer
var execution_timer: Timer
var recovery_timer: Timer
var hitbox_timer: Timer

# Signals
signal skill_ready
signal skill_started
signal skill_finished
signal skill_hit_enemy(enemy)
signal skill_level_changed(new_level)

# Virtual methods that can be overridden by child classes
func _init():
	# Initialize any resources needed for the skill
	pass

# Initialize the skill with reference to its owner
func initialize(skill_owner: Node) -> void:
	owner_node = skill_owner
	
	# Create and configure timers
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.name = skill_name + "_CooldownTimer"
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	
	execution_timer = Timer.new()
	execution_timer.one_shot = true
	execution_timer.name = skill_name + "_ExecutionTimer"
	execution_timer.timeout.connect(_on_execution_timeout)
	
	recovery_timer = Timer.new()
	recovery_timer.one_shot = true
	recovery_timer.name = skill_name + "_RecoveryTimer"
	recovery_timer.timeout.connect(_on_recovery_timeout)
	
	hitbox_timer = Timer.new()
	hitbox_timer.one_shot = true
	hitbox_timer.name = skill_name + "_HitboxTimer"
	hitbox_timer.timeout.connect(_on_hitbox_timeout)
	
	# Add timers to the owner node
	owner_node.add_child(cooldown_timer)
	owner_node.add_child(execution_timer)
	owner_node.add_child(recovery_timer)
	owner_node.add_child(hitbox_timer)

# Execute the skill in the given direction
func execute(direction: Vector2) -> bool:
	if is_on_cooldown or is_executing:
		return false
	
	last_use_direction = direction.normalized()
	is_executing = true
	
	# Start timers
	execution_timer.start(execution_time)
	cooldown_timer.start(cooldown_time)
	
	# Apply the skill effects
	_apply_skill_effects()
	
	# Spawn hitbox after delay if specified
	if hitbox_delay > 0:
		await owner_node.get_tree().create_timer(hitbox_delay).timeout
	
	# Spawn the hitbox if specified
	if hitbox_scene != null:
		_spawn_hitbox()
	
	emit_signal("skill_started")
	return true

# Called when the skill's cooldown is complete
func _on_cooldown_timeout() -> void:
	is_on_cooldown = false
	emit_signal("skill_ready")

# Called when the skill's execution time is complete
func _on_execution_timeout() -> void:
	is_executing = false
	recovery_timer.start(recovery_time)

# Called when the skill's recovery time is complete
func _on_recovery_timeout() -> void:
	emit_signal("skill_finished")

# Called when the hitbox duration is complete
func _on_hitbox_timeout() -> void:
	# Cleanup hitbox
	_cleanup_hitbox()

# Applies the effects of using the skill
func _apply_skill_effects() -> void:
	# Play animation
	if owner_node.has_method("play_animation"):
		owner_node.play_animation(animation_name)
	
	# Play sound effect if specified
	if skill_sfx != null:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = skill_sfx
		audio_player.one_shot = true
		owner_node.add_child(audio_player)
		audio_player.play()
		# Queue free after playing
		audio_player.finished.connect(func(): audio_player.queue_free())
	
	# Spawn visual effect if specified
	if skill_vfx_scene != null:
		var vfx = skill_vfx_scene.instantiate()
		owner_node.add_child(vfx)
		vfx.global_position = owner_node.global_position
		# VFX should handle its own cleanup

# Spawns the hitbox for the skill
func _spawn_hitbox() -> void:
	var hitbox_instance = hitbox_scene.instantiate()
	owner_node.add_child(hitbox_instance)
	
	# Position the hitbox based on the direction
	var offset = last_use_direction * hitbox_offset
	hitbox_instance.position = offset
	
	# Set the hitbox direction
	if hitbox_instance.has_method("set_direction"):
		hitbox_instance.set_direction(last_use_direction)
	
	# Configure hitbox properties
	if hitbox_instance.has_method("configure"):
		var config = {
			"damage": get_current_damage(),
			"knockback": knockback_force,
			"owner": owner_node
		}
		hitbox_instance.configure(config)
	
	# Connect signals if the hitbox emits them
	if hitbox_instance.has_signal("enemy_hit"):
		hitbox_instance.connect("enemy_hit", _on_enemy_hit)
	
	# Start the hitbox timer
	hitbox_timer.start(hitbox_duration)

# Clean up the hitbox
func _cleanup_hitbox() -> void:
	for child in owner_node.get_children():
		if child.is_in_group("skill_hitboxes") and child.get_meta("skill_name", "") == skill_name:
			child.queue_free()

# Called when the hitbox hits an enemy
func _on_enemy_hit(enemy) -> void:
	emit_signal("skill_hit_enemy", enemy)

# Level up the skill
func level_up() -> bool:
	if current_level < max_level:
		current_level += 1
		_apply_level_modifiers()
		emit_signal("skill_level_changed", current_level)
		return true
	return false

# Apply modifiers based on skill level
func _apply_level_modifiers() -> void:
	# Override in child classes to implement level-specific changes
	pass

# Get the current damage value based on level and modifiers
func get_current_damage() -> float:
	return base_damage * (1 + (current_level - 1) * 0.2)

# Get the current cooldown taking modifiers into account
func get_current_cooldown() -> float:
	return cooldown_time

# Get the remaining cooldown time
func get_cooldown_remaining() -> float:
	if !is_on_cooldown:
		return 0.0
	return cooldown_timer.time_left

# Get skill information as a dictionary
func get_info() -> Dictionary:
	return {
		"name": skill_name,
		"description": description,
		"cooldown": get_current_cooldown(),
		"damage": get_current_damage(),
		"level": current_level,
		"max_level": max_level,
		"icon": icon
	}
