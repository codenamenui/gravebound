extends CanvasLayer
class_name SkillUI

# References
@onready var skill_container = $SkillContainer
@onready var perk_container = $PerkContainer
@onready var health_bar = $HealthBar

var skill_manager: SkillManager
var perk_system: PerkSystem
var player: Player

# Skill slot UI elements
var skill_slots = []

func _ready():
	# Find player node
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("SkillUI could not find player node")
		return
	
	# Connect to player signals
	player.health_changed.connect(_on_player_health_changed)
	
	# Find skill manager and perk system
	for child in player.get_children():
		if child is SkillManager:
			skill_manager = child
		elif child is PerkSystem:
			perk_system = child
	
	if skill_manager == null:
		push_error("SkillUI could not find SkillManager node")
		return
	
	# Connect to skill manager signals
	skill_manager.skill_activated.connect(_on_skill_activated)
	skill_manager.skill_completed.connect(_on_skill_completed)
	skill_manager.skill_cooldown_finished.connect(_on_skill_cooldown_finished)
	
	# Connect to perk system signals if available
	if perk_system != null:
		perk_system.perk_unlocked.connect(_on_perk_unlocked)
		perk_system.perk_leveled_up.connect(_on_perk_leveled_up)
	
	# Initialize skill slots UI
	_initialize_skill_slots()
	
	# Set initial health
	if health_bar != null:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health

func _initialize_skill_slots():
	for i in range(skill_manager.max_skill_slots):
		var slot = _create_skill_slot(i)
		skill_container.add_child(slot)
		skill_slots.append(slot)
		
		# Update slot with skill info if available
		var skill = skill_manager.get_skill(i)
		if skill != null:
			_update_skill_slot(i, skill)

func _create_skill_slot(slot_index: int):
	var slot = Panel.new()
	slot.name = "SkillSlot" + str(slot_index)
	slot.custom_minimum_size = Vector2(50, 50)
	
	# Icon container
	var icon = TextureRect.new()
	icon.name = "Icon"
	#icon.expand_mode = TextureRect.EXPAND_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_FILL
	icon.size_flags_vertical = Control.SIZE_FILL
	slot.add_child(icon)
	
	# Cooldown overlay
	var cooldown = ColorRect.new()
	cooldown.name = "Cooldown"
	cooldown.color = Color(0, 0, 0, 0.5)
	cooldown.visible = false
	cooldown.size_flags_horizontal = Control.SIZE_FILL
	cooldown.size_flags_vertical = Control.SIZE_FILL
	slot.add_child(cooldown)
	
	# Key binding label
	var key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = str(slot_index + 1)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	slot.add_child(key_label)
	
	return slot

func _update_skill_slot(slot_index: int, skill: BaseSkill):
	if slot_index < 0 or slot_index >= skill_slots.size():
		return
	
	var slot = skill_slots[slot_index]
	var icon = slot.get_node("Icon")
	var cooldown = slot.get_node("Cooldown")
	
	# Update icon
	if skill.icon != null:
		icon.texture = skill.icon
	
	# Update cooldown visibility
	cooldown.visible = skill.is_on_cooldown

func _process(delta):
	# Update cooldown visuals
	for i in range(skill_slots.size()):
		var skill = skill_manager.get_skill(i)
		if skill != null and skill.is_on_cooldown:
			var slot = skill_slots[i]
			var cooldown = slot.get_node("Cooldown")
			
			# Calculate cooldown fill based on remaining time
			var remaining = skill.get_cooldown_remaining()
			var total = skill.get_current_cooldown()
			var ratio = remaining / total
			
			# Update the cooldown overlay to show remaining time
			cooldown.anchor_top = 1.0 - ratio
			cooldown.visible = ratio > 0.0

func _on_skill_activated(slot_index: int, skill: BaseSkill):
	if slot_index < 0 or slot_index >= skill_slots.size():
		return
	
	var slot = skill_slots[slot_index]
	var cooldown = slot.get_node("Cooldown")
	cooldown.visible = true
	cooldown.anchor_top = 0.0  # Full cooldown

func _on_skill_completed(slot_index: int, skill: BaseSkill):
	# This is just for skill completion, not cooldown
	pass

func _on_skill_cooldown_finished(slot_index: int, skill: BaseSkill):
	if slot_index < 0 or slot_index >= skill_slots.size():
		return
	
	var slot = skill_slots[slot_index]
	var cooldown = slot.get_node("Cooldown")
	cooldown.visible = false

func _on_perk_unlocked(perk_id: String):
	_update_perk_ui()

func _on_perk_leveled_up(perk_id: String, new_level: int):
	_update_perk_ui()

func _update_perk_ui():
	# Clear existing perk UI
	for child in perk_container.get_children():
		child.queue_free()
	
	# Add active perks
	if perk_system != null:
		var active_perks = perk_system.get_active_perks()
		for perk in active_perks:
			var perk_label = Label.new()
			perk_label.text = perk.name + " Lv." + str(perk.current_level)
			perk_container.add_child(perk_label)

func _on_player_health_changed(current: float, max_health: float):
	if health_bar != null:
		health_bar.max_value = max_health
		health_bar.value = current
