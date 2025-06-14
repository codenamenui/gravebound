extends Control
class_name PerkDisplay

# Perk data
var perk_data: PerkSelectionUI.Perk
var perk_index: int

# UI Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var effect_label: Label = $VBoxContainer/EffectLabel
@onready var button: Button = $Button
@onready var background: ColorRect = $Background

signal perk_clicked(perk_index: int)

func _ready():
	# Set up button to cover the entire perk area
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	
	# Make button transparent
	button.flat = true
	
	# Set up background
	background.color = Color(0.2, 0.2, 0.3, 0.8)  # Dark blue-gray background

func setup_perk(perk: PerkSelectionUI.Perk, index: int):
	perk_data = perk
	perk_index = index
	
	# Set title
	title_label.text = perk.name
	
	# Set description
	description_label.text = perk.description
	
	# Set effect text (more detailed breakdown)
	effect_label.text = _get_effect_text(perk)
	
	# Load and set sprite
	if ResourceLoader.exists(perk.icon_path):
		sprite.texture = load(perk.icon_path)
	else:
		# Create a simple colored square as fallback
		var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
		image.fill(_get_perk_color(perk))
		var texture = ImageTexture.new()
		texture.set_image(image)
		sprite.texture = texture

func _get_effect_text(perk: PerkSelectionUI.Perk) -> String:
	match perk.effect_type:
		"damage_bonus":
			return "Damage: +" + str(perk.effect_value)
		"damage_multiplier":
			var percent = (perk.effect_value - 1.0) * 100
			return "Damage: +" + str(percent) + "%"
		"speed_bonus":
			return "Speed: +" + str(perk.effect_value)
		"speed_multiplier":
			var percent = (perk.effect_value - 1.0) * 100
			return "Speed: +" + str(percent) + "%"
		"health_bonus":
			return "Health: +" + str(perk.effect_value_int)
		"max_health_bonus":
			return "Max Health: +" + str(perk.effect_value_int)
		"health_multiplier":
			var percent = (perk.effect_value - 1.0) * 100
			return "Health: +" + str(percent) + "%"
		"damage_reduction":
			return "Damage Reduction: +" + str(perk.effect_value)
		"damage_resistance":
			var percent = (1.0 - perk.effect_value) * 100
			return "Damage Resistance: +" + str(percent) + "%"
		"lifesteal":
			var percent = perk.effect_value * 100
			return "Lifesteal: +" + str(percent) + "%"
		"dash_bonus":
			return "Extra Dashes: +" + str(perk.effect_value_int)
		_:
			return "Unknown Effect"

func _get_perk_color(perk: PerkSelectionUI.Perk) -> Color:
	match perk.effect_type:
		"damage_bonus", "damage_multiplier":
			return Color.RED
		"speed_bonus", "speed_multiplier":
			return Color.GREEN
		"health_bonus", "max_health_bonus", "health_multiplier":
			return Color.BLUE
		"damage_reduction", "damage_resistance":
			return Color.ORANGE
		"lifesteal":
			return Color.PURPLE
		"dash_bonus":
			return Color.CYAN
		_:
			return Color.WHITE

func _on_button_pressed():
	emit_signal("perk_clicked", perk_index)

func _on_mouse_entered():
	# Highlight effect
	modulate = Color(1.2, 1.2, 1.2, 1.0)
	background.color = Color(0.3, 0.3, 0.4, 0.9)

func _on_mouse_exited():
	# Normal state
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	background.color = Color(0.2, 0.2, 0.3, 0.8)

func set_interactable(interactable: bool):
	button.disabled = !interactable
	if !interactable:
		modulate = Color(0.6, 0.6, 0.6, 1.0)
