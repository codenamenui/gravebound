extends Node
class_name SkillManager

# Skill slots
@export var max_skill_slots: int = 4
var equipped_skills: Array[BaseSkill] = []
var active_skill_index: int = 0

# Reference to the player/owner
var owner_node: CharacterBody2D

# Signals
signal skill_activated(skill_index, skill)
signal skill_completed(skill_index, skill)
signal skill_cooldown_finished(skill_index, skill)

func _ready():
	owner_node = get_parent()
	# Initialize empty skill array
	equipped_skills.resize(max_skill_slots)

func _input(event):
	# Skip processing if owner is in a state that prevents skill use
	if owner_node.is_dying or owner_node.is_hit:
		return
	
	# Handle skill activation via number keys (1-4)
	for i in range(max_skill_slots):
		if event.is_action_pressed("skill_" + str(i + 1)):
			activate_skill(i)
			break
	
	# Handle basic attack (could be skill slot 0)
	if event.is_action_pressed("attack"):
		activate_skill(0)  # Assuming slot 0 is the basic attack

# Equip a skill to a specific slot
func equip_skill(skill: BaseSkill, slot: int) -> bool:
	if slot < 0 or slot >= max_skill_slots:
		return false
	
	# If there's already a skill in this slot, unequip it
	if equipped_skills[slot] != null:
		unequip_skill(slot)
	
	# Initialize and equip the new skill
	skill.initialize(owner_node)
	equipped_skills[slot] = skill
	
	# Connect signals
	skill.skill_started.connect(_on_skill_started.bind(slot, skill))
	skill.skill_finished.connect(_on_skill_finished.bind(slot, skill))
	skill.skill_ready.connect(_on_skill_cooldown_finished.bind(slot, skill))
	
	return true

# Unequip a skill from a specific slot
func unequip_skill(slot: int) -> BaseSkill:
	if slot < 0 or slot >= max_skill_slots or equipped_skills[slot] == null:
		return null
		
	var skill = equipped_skills[slot]
	
	# Disconnect signals
	if skill.is_connected("skill_started", _on_skill_started):
		skill.skill_started.disconnect(_on_skill_started)
	if skill.is_connected("skill_finished", _on_skill_finished):
		skill.skill_finished.disconnect(_on_skill_finished)
	if skill.is_connected("skill_ready", _on_skill_cooldown_finished):
		skill.skill_ready.disconnect(_on_skill_cooldown_finished)
	
	equipped_skills[slot] = null
	return skill

# Activate the skill in the specified slot
func activate_skill(slot: int) -> bool:
	if slot < 0 or slot >= max_skill_slots or equipped_skills[slot] == null:
		return false
	
	# Get the current looking direction from the owner
	var direction = owner_node.last_direction
	
	# Try to execute the skill
	if await equipped_skills[slot].execute(direction):
		active_skill_index = slot
		return true
	
	return false

# Called when a skill is started
func _on_skill_started(slot: int, skill: BaseSkill) -> void:
	emit_signal("skill_activated", slot, skill)

# Called when a skill is finished
func _on_skill_finished(slot: int, skill: BaseSkill) -> void:
	emit_signal("skill_completed", slot, skill)

# Called when a skill's cooldown is finished
func _on_skill_cooldown_finished(slot: int, skill: BaseSkill) -> void:
	emit_signal("skill_cooldown_finished", slot, skill)

# Get all equipped skills
func get_all_skills() -> Array:
	return equipped_skills

# Get a specific skill by slot
func get_skill(slot: int) -> BaseSkill:
	if slot < 0 or slot >= max_skill_slots:
		return null
	return equipped_skills[slot]

# Check if a specific skill is on cooldown
func is_skill_on_cooldown(slot: int) -> bool:
	if slot < 0 or slot >= max_skill_slots or equipped_skills[slot] == null:
		return true
	return equipped_skills[slot].is_on_cooldown

# Get the remaining cooldown for a skill
func get_skill_cooldown_remaining(slot: int) -> float:
	if slot < 0 or slot >= max_skill_slots or equipped_skills[slot] == null:
		return 0.0
	return equipped_skills[slot].get_cooldown_remaining()
