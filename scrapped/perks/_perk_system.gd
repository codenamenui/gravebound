extends Node
class_name PerkSystem

# References
var owner_node: Node
var skill_manager: SkillManager

# Available perks
var available_perks: Dictionary = {}
# Active perks
var active_perks: Dictionary = {}

# Signals
signal perk_unlocked(perk_id)
signal perk_leveled_up(perk_id, new_level)

func _ready():
	owner_node = get_parent()
	
	# Find the SkillManager node
	for child in owner_node.get_children():
		if child is SkillManager:
			skill_manager = child
			break
	
	# Register built-in perks
	register_built_in_perks()

# Register all built-in perks
func register_built_in_perks() -> void:
	# Attack Speed Perk
	register_perk("attack_speed", {
		"name": "Swift Strikes",
		"description": "Increases attack speed by {value}%",
		"max_level": 5,
		"value_per_level": 10,
		"apply_function": func(level): 
			modify_all_skills_property("cooldown_time", 1.0 - (level * 0.1), true)
	})
	
	# Attack Damage Perk
	register_perk("attack_damage", {
		"name": "Mighty Blows",
		"description": "Increases attack damage by {value}%",
		"max_level": 5,
		"value_per_level": 15,
		"apply_function": func(level): 
			modify_all_skills_property("base_damage", 1.0 + (level * 0.15))
	})
	
	# Hitbox Size Perk
	register_perk("hitbox_size", {
		"name": "Extended Reach",
		"description": "Increases attack range by {value}%",
		"max_level": 3,
		"value_per_level": 20,
		"apply_function": func(level): 
			modify_all_skills_property("hitbox_offset", 1.0 + (level * 0.2))
	})
	
	# Combo Master Perk (specific to BasicAttackSkill)
	register_perk("combo_master", {
		"name": "Combo Master",
		"description": "Extends combo window by {value}%",
		"max_level": 3,
		"value_per_level": 25,
		"apply_function": func(level): 
			for slot in range(skill_manager.max_skill_slots):
				var skill = skill_manager.get_skill(slot)
				if skill is BasicAttackSkill:
					skill.combo_window_time = skill.combo_window_time * (1.0 + (level * 0.25))
	})

# Register a new perk
func register_perk(perk_id: String, perk_data: Dictionary) -> void:
	if available_perks.has(perk_id):
		push_warning("Perk with ID " + perk_id + " already exists")
		return
	
	# Ensure perk data has required fields
	if not perk_data.has("name") or not perk_data.has("description") or not perk_data.has("max_level") or not perk_data.has("apply_function"):
		push_error("Perk data missing required fields")
		return
	
	# Add default values if not specified
	if not perk_data.has("current_level"):
		perk_data["current_level"] = 0
	
	available_perks[perk_id] = perk_data

# Unlock a perk or level it up if already unlocked
func unlock_perk(perk_id: String) -> bool:
	if not available_perks.has(perk_id):
		push_warning("Perk with ID " + perk_id + " does not exist")
		return false
	
	var perk = available_perks[perk_id]
	
	# Check if the perk is already at max level
	if perk.current_level >= perk.max_level:
		return false
	
	# Level up the perk
	perk.current_level += 1
	
	# Add to active perks if not already active
	if not active_perks.has(perk_id):
		active_perks[perk_id] = perk
		emit_signal("perk_unlocked", perk_id)
	else:
		active_perks[perk_id] = perk
		emit_signal("perk_leveled_up", perk_id, perk.current_level)
	
	# Apply the perk effect
	if perk.has("apply_function") and perk.apply_function is Callable:
		perk.apply_function.call(perk.current_level)
	
	return true

# Modify a property for all skills
func modify_all_skills_property(property_name: String, modifier: float, is_multiplier: bool = false) -> void:
	for slot in range(skill_manager.max_skill_slots):
		var skill = skill_manager.get_skill(slot)
		if skill != null and skill.has(property_name):
			if is_multiplier:
				skill[property_name] *= modifier
			else:
				skill[property_name] = skill[property_name] * modifier

# Get perk information
func get_perk_info(perk_id: String) -> Dictionary:
	if not available_perks.has(perk_id):
		return {}
	
	var perk = available_perks[perk_id]
	var info = {
		"id": perk_id,
		"name": perk.name,
		"description": perk.description.replace("{value}", str(perk.value_per_level * perk.current_level)),
		"current_level": perk.current_level,
		"max_level": perk.max_level,
		"is_max_level": perk.current_level >= perk.max_level
	}
	
	return info

# Get all active perks
func get_active_perks() -> Array:
	var perks = []
	for perk_id in active_perks:
		perks.append(get_perk_info(perk_id))
	return perks

# Get all available perks (active and inactive)
func get_all_perks() -> Array:
	var perks = []
	for perk_id in available_perks:
		perks.append(get_perk_info(perk_id))
	return perks
