extends Control
class_name PerkSelectionUI

# Perk data structure
class Perk:
	var id: String
	var name: String
	var description: String
	var icon_path: String
	var weight: float  # Higher weight = more likely to appear
	var effect_type: String
	var effect_value: float
	var effect_value_int: int
	
	func _init(p_id: String, p_name: String, p_desc: String, p_icon: String, p_weight: float, p_type: String, p_value: float = 0.0, p_value_int: int = 0):
		id = p_id
		name = p_name
		description = p_desc
		icon_path = p_icon
		weight = p_weight
		effect_type = p_type
		effect_value = p_value
		effect_value_int = p_value_int

# Available perks pool
var available_perks: Array[Perk] = []
var selected_perks: Array[Perk] = []

# References to your existing perk nodes
@onready var perk1: PerkDisplay = $Perk1
@onready var perk2: PerkDisplay = $Perk2
@onready var perk3: PerkDisplay = $Perk3

# Optional UI elements
@onready var title_label: Label = $TitleLabel  # Optional
@onready var background: ColorRect = $Background  # Optional

var perk_displays: Array[PerkDisplay] = []

# Player reference
var player: Player

signal perk_selected(perk: Perk)

func _ready():
	_initialize_perks()
	_setup_ui()
	hide()  # Hidden by default

func _initialize_perks():
	# Damage perks
	available_perks.append(Perk.new("dmg_bonus_small", "Minor Damage", "Increases your base damage by a small amount", "res://icons/damage_small.png", 25.0, "damage_bonus", 5.0))
	available_perks.append(Perk.new("dmg_bonus_medium", "Moderate Damage", "Increases your base damage by a moderate amount", "res://icons/damage_medium.png", 15.0, "damage_bonus", 10.0))
	available_perks.append(Perk.new("dmg_bonus_large", "Major Damage", "Significantly increases your base damage", "res://icons/damage_large.png", 5.0, "damage_bonus", 20.0))
	
	# Damage multiplier perks
	available_perks.append(Perk.new("dmg_mult_small", "Sharpened Blade", "Your attacks deal more damage", "res://icons/damage_mult_small.png", 20.0, "damage_multiplier", 1.1))
	available_perks.append(Perk.new("dmg_mult_medium", "Berserker's Fury", "Enter a rage state that amplifies damage", "res://icons/damage_mult_medium.png", 10.0, "damage_multiplier", 1.25))
	available_perks.append(Perk.new("dmg_mult_large", "Divine Strength", "Channel divine power for devastating attacks", "res://icons/damage_mult_large.png", 3.0, "damage_multiplier", 1.5))
	
	# Speed perks
	available_perks.append(Perk.new("speed_bonus_small", "Swift Steps", "Move faster across the battlefield", "res://icons/speed_small.png", 25.0, "speed_bonus", 30.0))
	available_perks.append(Perk.new("speed_bonus_medium", "Wind Walker", "Harness the wind to boost your speed", "res://icons/speed_medium.png", 15.0, "speed_bonus", 50.0))
	available_perks.append(Perk.new("speed_mult_small", "Fleet Footed", "Your natural agility is enhanced", "res://icons/speed_mult_small.png", 20.0, "speed_multiplier", 1.15))
	available_perks.append(Perk.new("speed_mult_medium", "Lightning Reflexes", "Move with lightning-like speed", "res://icons/speed_mult_medium.png", 8.0, "speed_multiplier", 1.3))
	
	# Health perks
	available_perks.append(Perk.new("health_bonus_small", "Vitality Boost", "Feel more energized and healthy", "res://icons/health_small.png", 25.0, "health_bonus", 0.0, 20))
	available_perks.append(Perk.new("health_bonus_medium", "Hardy Constitution", "Your body becomes more resilient", "res://icons/health_medium.png", 15.0, "health_bonus", 0.0, 50))
	available_perks.append(Perk.new("max_health_bonus", "Robust Body", "Permanently increase your maximum health", "res://icons/max_health.png", 20.0, "max_health_bonus", 0.0, 30))
	available_perks.append(Perk.new("health_mult", "Troll Regeneration", "Your body heals like a mythical troll", "res://icons/health_mult.png", 10.0, "health_multiplier", 1.2))
	
	# Defense perks
	available_perks.append(Perk.new("dmg_reduction_small", "Thick Skin", "Your skin hardens against attacks", "res://icons/defense_small.png", 20.0, "damage_reduction", 3.0))
	available_perks.append(Perk.new("dmg_reduction_medium", "Iron Hide", "Your body becomes as tough as iron", "res://icons/defense_medium.png", 12.0, "damage_reduction", 7.0))
	available_perks.append(Perk.new("dmg_resistance_small", "Armor Training", "Learn to deflect incoming attacks", "res://icons/resistance_small.png", 18.0, "damage_resistance", 0.9))
	available_perks.append(Perk.new("dmg_resistance_medium", "Defensive Mastery", "Master the art of damage mitigation", "res://icons/resistance_medium.png", 8.0, "damage_resistance", 0.8))
	
	# Utility perks
	available_perks.append(Perk.new("lifesteal_small", "Vampiric Touch", "Drain life from your enemies", "res://icons/lifesteal_small.png", 15.0, "lifesteal", 0.1))
	available_perks.append(Perk.new("lifesteal_medium", "Blood Drinker", "Feast on the life force of your foes", "res://icons/lifesteal_medium.png", 8.0, "lifesteal", 0.2))
	available_perks.append(Perk.new("dash_bonus", "Extra Dash", "Gain an additional dash charge", "res://icons/dash_bonus.png", 12.0, "dash_bonus", 0.0, 1))
	available_perks.append(Perk.new("dash_bonus_rare", "Dash Master", "Master of evasive maneuvers", "res://icons/dash_bonus_rare.png", 4.0, "dash_bonus", 0.0, 2))

func _setup_ui():
	# Collect perk display references
	perk_displays = [perk1, perk2, perk3]
	
	# Connect signals from each perk display
	for i in range(perk_displays.size()):
		var perk_display = perk_displays[i]
		if perk_display:
			perk_display.perk_clicked.connect(_on_perk_selected)
	
	# Set up optional UI elements
	if title_label:
		title_label.text = "Choose Your Perk"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if background:
		background.color = Color(0, 0, 0, 0.8)  # Semi-transparent black

func show_perk_selection(p_player: Player):
	player = p_player
	selected_perks = _select_random_perks(3)
	_update_perk_displays()
	show()
	get_tree().paused = true  # Pause the game

func _select_random_perks(count: int) -> Array[Perk]:
	var result: Array[Perk] = []
	var weighted_pool: Array[Perk] = []
	
	# Create weighted pool
	for perk in available_perks:
		var weight_count = int(perk.weight)
		for i in range(weight_count):
			weighted_pool.append(perk)
	
	# Select unique perks
	var used_perks: Array[String] = []
	while result.size() < count and weighted_pool.size() > 0:
		var random_index = randi() % weighted_pool.size()
		var selected_perk = weighted_pool[random_index]
		
		if not used_perks.has(selected_perk.id):
			result.append(selected_perk)
			used_perks.append(selected_perk.id)
		
		# Remove all instances of this perk from the pool
		weighted_pool = weighted_pool.filter(func(p): return p.id != selected_perk.id)
	
	return result

func _update_perk_displays():
	for i in range(min(selected_perks.size(), perk_displays.size())):
		var perk = selected_perks[i]
		var display = perk_displays[i]
		
		if display:
			display.setup_perk(perk, i)
			display.set_interactable(true)
			display.show()
	
	# Hide unused displays
	for i in range(selected_perks.size(), perk_displays.size()):
		if perk_displays[i]:
			perk_displays[i].hide()

func _on_perk_selected(perk_index: int):
	if perk_index >= selected_perks.size():
		return
	
	var selected_perk = selected_perks[perk_index]
	_apply_perk_to_player(selected_perk)
	
	# Disable all perk displays
	for display in perk_displays:
		if display:
			display.set_interactable(false)
	
	emit_signal("perk_selected", selected_perk)
	
	# Small delay before hiding for visual feedback
	await get_tree().create_timer(0.3).timeout
	
	hide()
	get_tree().paused = false  # Unpause the game

func _apply_perk_to_player(perk: Perk):
	if not player:
		return
	
	match perk.effect_type:
		"damage_bonus":
			player.add_damage_bonus(perk.effect_value)
		"damage_multiplier":
			player.add_damage_multiplier(perk.effect_value)
		"speed_bonus":
			player.add_speed_bonus(perk.effect_value)
		"speed_multiplier":
			player.add_movement_speed_multiplier(perk.effect_value)
		"health_bonus":
			player.add_health_bonus(perk.effect_value_int)
		"max_health_bonus":
			player.add_max_health_bonus(perk.effect_value_int)
		"health_multiplier":
			player.add_health_multiplier(perk.effect_value)
		"damage_reduction":
			player.add_damage_reduction(perk.effect_value)
		"damage_resistance":
			player.add_damage_resistance(perk.effect_value)
		"lifesteal":
			player.add_lifesteal(perk.effect_value)
		"dash_bonus":
			player.add_dash_count_bonus(perk.effect_value_int)

func hide_perk_selection():
	hide()
	get_tree().paused = false

# Function to add custom perks at runtime
func add_custom_perk(id: String, name: String, description: String, icon_path: String, weight: float, effect_type: String, effect_value: float = 0.0, effect_value_int: int = 0):
	var new_perk = Perk.new(id, name, description, icon_path, weight, effect_type, effect_value, effect_value_int)
	available_perks.append(new_perk)

# Function to modify perk weights
func set_perk_weight(perk_id: String, new_weight: float):
	for perk in available_perks:
		if perk.id == perk_id:
			perk.weight = new_weight
			break
