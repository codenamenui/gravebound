extends Node
class_name SkillManagerComponent

signal skill_equipped(slot_index, skill)
signal skill_unequipped(slot_index)
signal skill_executed(skill)
signal skill_ready(skill)
signal skill_finished(skill)
signal skill_hit_enemy(skill, enemy)

@export var max_skill_slots: int = 4

enum SkillCategory {
	BASIC_ATTACK,
	MOVEMENT_SKILL,
	UTILITY_SKILL,
	SPECIAL_SKILL
}

var character: CharacterBody2D
var equipped_skills: Array = []
var skill_categories: Dictionary = {
	SkillCategory.BASIC_ATTACK: [],
	SkillCategory.MOVEMENT_SKILL: [],
	SkillCategory.UTILITY_SKILL: [],
	SkillCategory.SPECIAL_SKILL: []
}

func _ready():
	equipped_skills.resize(max_skill_slots)

func initialize(character_node: CharacterBody2D):
	character = character_node

func equip_skill(skill: BaseSkill, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return false

	if equipped_skills[slot_index] != null:
		unequip_skill(slot_index)

	if !skill.is_inside_tree():
		_initialize_skill(skill)

	equipped_skills[slot_index] = skill
	emit_signal("skill_equipped", slot_index, skill)
	return true

func unequip_skill(slot_index: int) -> BaseSkill:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return null

	var skill = equipped_skills[slot_index]
	if skill != null:
		equipped_skills[slot_index] = null
		emit_signal("skill_unequipped", slot_index)
	return skill

func add_skill(skill: BaseSkill, category: int) -> void:
	if !skill_categories.has(category):
		push_error("Invalid skill category: " + str(category))
		return

	_initialize_skill(skill)
	if !skill_categories[category].has(skill):
		skill_categories[category].append(skill)

func _initialize_skill(skill: BaseSkill) -> void:
	skill.initialize(character)
	add_child(skill)

	if !skill.is_connected("skill_ready", _on_skill_ready):
		skill.skill_ready.connect(_on_skill_ready.bind(skill))
	if !skill.is_connected("skill_finished", _on_skill_finished):
		skill.skill_finished.connect(_on_skill_finished.bind(skill))
	if !skill.is_connected("skill_hit_enemy", _on_skill_hit_enemy):
		skill.skill_hit_enemy.connect(_on_skill_hit_enemy.bind(skill))

func execute_skill(slot_index: int, direction: Vector2 = Vector2.RIGHT) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		push_error("Invalid skill slot index: " + str(slot_index))
		return false

	var skill = equipped_skills[slot_index]
	if skill and not skill.is_skill_active() and not skill.is_on_cooldown:
		return _execute_skill(skill, direction)

	return false

func execute_skill_by_category(category: int, skill_index: int = 0, direction: Vector2 = Vector2.RIGHT) -> bool:
	if !skill_categories.has(category) or skill_index < 0 or skill_index >= skill_categories[category].size():
		return false

	var skill = skill_categories[category][skill_index]
	if skill and not skill.is_skill_active() and not skill.is_on_cooldown:
		return _execute_skill(skill, direction)

	return false

func _execute_skill(skill: BaseSkill, direction: Vector2) -> bool:
	if character.current_skill and character.current_skill.is_skill_active():
		return false

	var success = skill.execute(direction)
	if success:
		character.current_skill = skill
		emit_signal("skill_executed", skill)
	return success

func _on_skill_ready(skill: BaseSkill):
	emit_signal("skill_ready", skill)

func _on_skill_finished(skill: BaseSkill):
	emit_signal("skill_finished", skill)

func _on_skill_hit_enemy(enemy, skill: BaseSkill):
	emit_signal("skill_hit_enemy", skill, enemy)

func get_equipped_skill(slot_index: int) -> BaseSkill:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return null
	return equipped_skills[slot_index]

func get_skills_by_category(category: int) -> Array:
	return skill_categories.get(category, [])

func get_all_skills() -> Array:
	var all_skills: Array = []
	for skill in equipped_skills:
		if skill != null and !all_skills.has(skill):
			all_skills.append(skill)
	for category in skill_categories.values():
		for skill in category:
			if !all_skills.has(skill):
				all_skills.append(skill)
	return all_skills

func can_use_skill(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= max_skill_slots:
		return false
	var skill = equipped_skills[slot_index]
	return skill != null and not skill.is_skill_active() and not skill.is_on_cooldown

func can_use_skill_by_category(category: int, skill_index: int = 0) -> bool:
	if !skill_categories.has(category) or skill_index < 0 or skill_index >= skill_categories[category].size():
		return false
	var skill = skill_categories[category][skill_index]
	return not skill.is_skill_active() and not skill.is_on_cooldown

func process_input(input_direction: Vector2, action_pressed: Dictionary) -> void:
	if character.current_skill and character.current_skill.is_skill_active():
		if character.current_skill.can_change_direction_during_skill:
			character.current_skill.last_use_direction = input_direction.normalized()
		return

	var effective_direction = input_direction.normalized() if input_direction.length() > 0 else character.facing_direction

	for i in range(max_skill_slots):
		if action_pressed.get("skill_%d" % (i + 1), false):
			execute_skill(i, effective_direction)

	if action_pressed.get("attack", -1) >= 0:
		execute_skill_by_category(SkillCategory.BASIC_ATTACK, action_pressed.get("attack", -1), effective_direction)

	if action_pressed.get("dash", false):
		execute_skill_by_category(SkillCategory.MOVEMENT_SKILL, 0, effective_direction)
