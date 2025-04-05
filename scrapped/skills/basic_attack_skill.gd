extends BaseSkill
class_name BasicAttackSkill

# Additional properties specific to the basic attack
@export var combo_window_time: float = 0.5
@export var max_combo_hits: int = 3

var current_combo: int = 0
var combo_timer: Timer

func _init():
	skill_name = "Basic Attack"
	description = "A basic melee attack"
	cooldown_time = 0.5
	execution_time = 0.3
	recovery_time = 0.2
	speed_multiplier = 0.7
	animation_name = "attack"
	base_damage = 10.0
	hitbox_duration = 0.2
	hitbox_offset = 30.0

func initialize(skill_owner: Node) -> void:
	super.initialize(skill_owner)
	
	# Create combo timer
	combo_timer = Timer.new()
	combo_timer.one_shot = true
	combo_timer.name = skill_name + "_ComboTimer"
	combo_timer.timeout.connect(_on_combo_timeout)
	owner_node.add_child(combo_timer)

func execute(direction: Vector2) -> bool:
	if is_executing:
		# Don't allow new execution if already executing
		return false
	
	# Reset cooldown to allow combo chains
	is_on_cooldown = false
	if cooldown_timer.is_inside_tree():
		cooldown_timer.stop()
	
	# Increment combo if within combo window
	if combo_timer.time_left > 0:
		current_combo = (current_combo + 1) % max_combo_hits
	else:
		current_combo = 0
	
	# Start combo timer to track window for next hit
	combo_timer.start(combo_window_time)
	
	# Change animation based on combo counter
	animation_name = "attack_" + str(current_combo + 1)
	
	# Execute the attack
	return await super.execute(direction)

func _apply_skill_effects() -> void:
	super._apply_skill_effects()
	
	# Apply combo specific effects
	match current_combo:
		0: # First hit
			base_damage = 10.0
			knockback_force = 100.0
		1: # Second hit
			base_damage = 15.0
			knockback_force = 150.0
		2: # Third hit
			base_damage = 25.0
			knockback_force = 250.0

func _on_combo_timeout() -> void:
	current_combo = 0

func _apply_level_modifiers() -> void:
	# Modify base stats based on skill level
	base_damage = 10.0 * (1 + (current_level - 1) * 0.25)
	knockback_force = 100.0 * (1 + (current_level - 1) * 0.15)
	cooldown_time = max(0.2, 0.5 - (current_level - 1) * 0.05)
