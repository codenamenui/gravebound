extends Node
class_name SkillManagerComponent

signal skill_equipped(slot_index, skill)
signal skill_unequipped(slot_index)
signal skill_executed(skill)
signal skill_ready(skill)
signal skill_finished(skill)
signal skill_hit_enemy(skill, enemy)

# Configuration
@export var max_skill_slots: int = 4
@export_group("AI Skill Settings")
@export var enable_random_skills_for_ai: bool = false
@export var ai_skill_chance: float = 0.3
@export var ai_skill_cooldown: float = 3.0
@export var ai_skill_weights: Dictionary = {
	"basic_attack": 40,
	"movement_skill": 30,
	"equipped_skill": 30
}

# Skill categories
enum SkillCategory {
	BASIC_ATTACK,
	MOVEMENT_SKILL,
	UTILITY_SKILL,
	SPECIAL_SKILL
}

# Core reference to the character using this component
var character: CharacterBody2D
var equipped_skills: Array = []
var skill_categories: Dictionary = {
	SkillCategory.BASIC_ATTACK: [],
	SkillCategory.MOVEMENT_SKILL: [],
	SkillCategory.UTILITY_SKILL: [],
	SkillCategory.SPECIAL_SKILL: []
}

# AI variables
var ai_skill_timer: Timer
var is_ai_controlled: bool = false

func _ready():
	# Initialize arrays
	equipped_skills.resize(max_skill_slots)
	
	# Set up AI timer if needed
	if enable_random_skills_for_ai:
		ai_skill_timer = Timer.new()
		ai_skill_timer.one_shot = false
		ai_skill_timer.wait_time = ai_skill_cooldown
		ai_skill_timer.timeout.connect(_on_ai_skill_timer_timeout)
		add_child(ai_skill_timer)

func initialize(character_node: CharacterBody2D, is_ai: bool = false):
	character = character_node
	is_ai_controlled = is_ai
	
	if is_ai_controlled and enable_random_skills_for_ai:
		ai_skill_timer.start()

# Core skill management functions
func equip_skill(skill: BaseSkill, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return false
	
	# Unequip current skill in this slot if any
	if equipped_skills[slot_index] != null:
		unequip_skill(slot_index)
	
	# Initialize the skill if it hasn't been initialized yet
	if !skill.is_inside_tree():
		_initialize_skill(skill)
	
	# Store the skill
	equipped_skills[slot_index] = skill
	
	emit_signal("skill_equipped", slot_index, skill)
	return true

func unequip_skill(slot_index: int) -> BaseSkill:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return null
		
	var skill = equipped_skills[slot_index]
	if skill != null:
		# Remove from array
		equipped_skills[slot_index] = null
		
		emit_signal("skill_unequipped", slot_index)
		return skill
	
	return null

# New improved methods for adding skills with categorization
func add_skill(skill: BaseSkill, category: int) -> void:
	if !skill_categories.has(category):
		push_error("Invalid skill category: " + str(category))
		return
	
	_initialize_skill(skill)
	skill_categories[category].append(skill)
	
	# For backward compatibility
	if category == SkillCategory.BASIC_ATTACK:
		# Previous code referred to these directly
		add_basic_attack(skill)
	elif category == SkillCategory.MOVEMENT_SKILL:
		# Previous code referred to these directly
		add_movement_skill(skill)

# These methods are kept for backward compatibility
func add_basic_attack(attack: BaseSkill) -> void:
	_initialize_skill(attack)
	
	# Only add if not already in the array
	if !skill_categories[SkillCategory.BASIC_ATTACK].has(attack):
		skill_categories[SkillCategory.BASIC_ATTACK].append(attack)

func add_movement_skill(skill: BaseSkill) -> void:
	_initialize_skill(skill)
	
	# Only add if not already in the array
	if !skill_categories[SkillCategory.MOVEMENT_SKILL].has(skill):
		skill_categories[SkillCategory.MOVEMENT_SKILL].append(skill)

# Centralized skill initialization
func _initialize_skill(skill: BaseSkill) -> void:
	# Only initialize if not already initialized
	if !skill.is_inside_tree():
		skill.initialize(character)
		add_child(skill)
		
		# Connect signals
		if !skill.is_connected("skill_ready", _on_skill_ready):
			skill.skill_ready.connect(_on_skill_ready.bind(skill))
		
		if !skill.is_connected("skill_finished", _on_skill_finished):
			skill.skill_finished.connect(_on_skill_finished.bind(skill))
		
		if !skill.is_connected("skill_hit_enemy", _on_skill_hit_enemy):
			skill.skill_hit_enemy.connect(_on_skill_hit_enemy.bind(skill))

# Skill execution functions
func execute_skill(slot_index: int, direction: Vector2 = Vector2.RIGHT) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return false
		
	var skill = equipped_skills[slot_index]
	if skill != null and not skill.is_skill_active() and not skill.is_on_cooldown:
		return _execute_skill(skill, direction)
	
	return false

func execute_skill_by_category(category: int, skill_index: int = 0, direction: Vector2 = Vector2.RIGHT) -> bool:
	if !skill_categories.has(category) or skill_index < 0 or skill_index >= skill_categories[category].size():
		return false
		
	var skill = skill_categories[category][skill_index]
	if skill != null and not skill.is_skill_active() and not skill.is_on_cooldown:
		return _execute_skill(skill, direction)
	
	return false

func execute_basic_attack(attack_index: int = 0, direction: Vector2 = Vector2.RIGHT) -> bool:
	return execute_skill_by_category(SkillCategory.BASIC_ATTACK, attack_index, direction)

func execute_movement_skill(skill_index: int = 0, direction: Vector2 = Vector2.RIGHT) -> bool:
	return execute_skill_by_category(SkillCategory.MOVEMENT_SKILL, skill_index, direction)

func _execute_skill(skill: BaseSkill, direction: Vector2) -> bool:
	if character.current_skill != null and character.current_skill.is_skill_active():
		# Don't interrupt an ongoing skill unless it's configured to allow that
		return false
	
	var success = skill.execute(direction)
	if success:
		character.current_skill = skill
		emit_signal("skill_executed", skill)
	
	return success

# AI skill execution
func _on_ai_skill_timer_timeout():
	if not is_ai_controlled or character.current_skill != null:
		return
	
	# Roll chance to use a skill
	if randf() > ai_skill_chance:
		return
	
	# Get direction toward target (if available) or random direction
	var direction = _get_ai_direction()
	
	# Choose skill type based on weights
	var skill_type = _weighted_random_selection(ai_skill_weights)
	var skill_used = false
	
	match skill_type:
		"basic_attack":
			skill_used = _try_execute_random_skill(SkillCategory.BASIC_ATTACK, direction)
		"movement_skill":
			skill_used = _try_execute_random_skill(SkillCategory.MOVEMENT_SKILL, direction)
		"equipped_skill":
			skill_used = _try_execute_random_equipped_skill(direction)
	
	# If selected skill type couldn't be used, try any available skill
	if !skill_used:
		for category in skill_categories.keys():
			if _try_execute_random_skill(category, direction):
				skill_used = true
				break
		
		if !skill_used and equipped_skills.size() > 0:
			_try_execute_random_equipped_skill(direction)

func _get_ai_direction() -> Vector2:
	# If character has an AI component with target information, use that
	if character.has_method("get_target_direction"):
		var target_direction = character.get_target_direction()
		if target_direction.length() > 0:
			return target_direction
	
	# Fallback to random direction
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _try_execute_random_skill(category: int, direction: Vector2) -> bool:
	var skills = skill_categories[category]
	if skills.size() == 0:
		return false
	
	# Shuffle skills to try them in random order
	skills.shuffle()
	
	for skill in skills:
		if not skill.is_skill_active() and not skill.is_on_cooldown:
			return _execute_skill(skill, direction)
	
	return false

func _try_execute_random_equipped_skill(direction: Vector2) -> bool:
	var valid_slots = []
	for i in range(equipped_skills.size()):
		if equipped_skills[i] != null and not equipped_skills[i].is_on_cooldown:
			valid_slots.append(i)
			
	if valid_slots.size() > 0:
		var slot_index = valid_slots[randi() % valid_slots.size()]
		return execute_skill(slot_index, direction)
	
	return false

func _weighted_random_selection(weights: Dictionary) -> String:
	var total_weight = 0
	for key in weights:
		total_weight += weights[key]
	
	var random_value = randf() * total_weight
	var current_sum = 0
	
	for key in weights:
		current_sum += weights[key]
		if random_value <= current_sum:
			return key
	
	# Default to first key if something goes wrong
	return weights.keys()[0]

# Signal callbacks
func _on_skill_ready(skill: BaseSkill):
	emit_signal("skill_ready", skill)

func _on_skill_finished(skill: BaseSkill):
	emit_signal("skill_finished", skill)

func _on_skill_hit_enemy(enemy, skill: BaseSkill):
	emit_signal("skill_hit_enemy", skill, enemy)

# Utility functions
func get_equipped_skill(slot_index: int) -> BaseSkill:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return null
	return equipped_skills[slot_index]

func get_skills_by_category(category: int) -> Array:
	if skill_categories.has(category):
		return skill_categories[category]
	return []

func get_all_skills() -> Array:
	var all_skills = []
	
	# Add equipped skills
	for skill in equipped_skills:
		if skill != null and !all_skills.has(skill):
			all_skills.append(skill)
	
	# Add all categorized skills
	for category in skill_categories.values():
		for skill in category:
			if !all_skills.has(skill):
				all_skills.append(skill)
	
	return all_skills

func can_use_skill(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return false
		
	var skill = equipped_skills[slot_index]
	if skill == null:
		return false
		
	return not skill.is_skill_active() and not skill.is_on_cooldown

func can_use_skill_by_category(category: int, skill_index: int = 0) -> bool:
	if !skill_categories.has(category) or skill_index < 0 or skill_index >= skill_categories[category].size():
		return false
		
	var skill = skill_categories[category][skill_index]
	return not skill.is_skill_active() and not skill.is_on_cooldown

func can_use_basic_attack(attack_index: int = 0) -> bool:
	return can_use_skill_by_category(SkillCategory.BASIC_ATTACK, attack_index)

func can_use_movement_skill(skill_index: int = 0) -> bool:
	return can_use_skill_by_category(SkillCategory.MOVEMENT_SKILL, skill_index)

# Handle input for player character
func process_input(input_direction: Vector2, action_pressed: Dictionary) -> void:
	if character.current_skill != null and character.current_skill.is_skill_active():
		# Don't allow new skills while one is active unless it's configured differently
		if character.current_skill.can_change_direction_during_skill:
			# Update the skill's direction if allowed
			character.current_skill.last_use_direction = input_direction.normalized()
		return
	
	# Get effective direction - use input direction if available, otherwise use character's facing
	var effective_direction = input_direction.normalized() if input_direction.length() > 0 else character.facing_direction
	
	# Process skill inputs - customize these based on your input mapping
	if action_pressed.get("skill_1", false):
		execute_skill(0, effective_direction)
	
	if action_pressed.get("skill_2", false):
		execute_skill(1, effective_direction)
		
	if action_pressed.get("skill_3", false):
		execute_skill(2, effective_direction)
		
	if action_pressed.get("skill_4", false):
		execute_skill(3, effective_direction)
	
	if action_pressed.get("attack", false):
		execute_basic_attack(0, effective_direction)
	
	if action_pressed.get("dash", false):
		execute_movement_skill(0, effective_direction)
