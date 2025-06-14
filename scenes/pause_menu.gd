extends Control

@onready var stats_container = $StatsContainer
@onready var buttons_container = $ButtonsContainer

# Stat labels
@onready var health_label = $StatsContainer/HealthLabel
@onready var damage_label = $StatsContainer/DamageLabel
@onready var speed_label = $StatsContainer/SpeedLabel
@onready var dash_count_label = $StatsContainer/DashCountLabel
@onready var damage_reduction_label = $StatsContainer/DamageReductionLabel
@onready var damage_resistance_label = $StatsContainer/DamageResistanceLabel
@onready var lifesteal_label = $StatsContainer/LifestealLabel

var player: Player

func _ready():
	# Find the player node
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		# Alternative way to find player
		player = get_node_or_null("/root/Game/Player")
	
	_update_stats_display()

func _on_play_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.PLAYING)

func _on_settings_pressed() -> void:
	GameData.from_game = true
	SceneManager.transition_to_state(GameData.GameState.SETTINGS)

func _on_main_menu_pressed() -> void:
	SceneManager.transition_to_state(GameData.GameState.MAIN_MENU)

func _update_stats_display():
	# Add more comprehensive null checks
	if not player:
		print("Player is null")
		return
	
	if not is_instance_valid(player):
		print("Player instance is not valid")
		return
		
	if not player.health_component:
		print("Health component is null - trying to get it...")
		# Try to get the health component directly
		player.health_component = player.get_node_or_null("HealthComponent")
		if not player.health_component:
			print("Still couldn't find health component")
			return
	
	print("Updating stats - health component found!")
	
	# Update health display
	var current_health = player.health_component.current_health
	var max_health = player.health_component.max_health
	health_label.text = "Health: %d / %d" % [current_health, max_health]
	
	# Update damage display
	var total_damage = player.get_total_damage()
	damage_label.text = "Damage: %.1f (Base: %.1f + %.1f) × %.2f" % [
		total_damage,
		0.0, # Base damage would need to be tracked separately
		player.additional_damage,
		player.damage_multiplier
	]
	
	# Update speed display
	var total_speed = player.get_total_speed()
	speed_label.text = "Speed: %.1f (Base: %.1f + %.1f) × %.2f" % [
		total_speed,
		player.base_speed,
		player.speed_bonus,
		player.movement_speed_multiplier
	]
	
	# Update dash count
	var max_dashes = player.get_max_dashes()
	dash_count_label.text = "Max Dashes: %d (Base: 3 + %d)" % [max_dashes, player.max_dash_bonus]
	
	# Update damage reduction
	damage_reduction_label.text = "Damage Reduction: %.1f" % player.damage_reduction
	
	# Update damage resistance (show as percentage)
	var resistance_percent = (1.0 - player.damage_resistance) * 100.0
	damage_resistance_label.text = "Damage Resistance: %.1f%%" % resistance_percent
	
	# Update lifesteal
	var lifesteal_percent = player.lifesteal_percent * 100.0
	lifesteal_label.text = "Lifesteal: %.1f%%" % lifesteal_percent

# Call this function when the pause menu becomes visible
func _on_visibility_changed():
	if visible:
		_update_stats_display()
