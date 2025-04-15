extends Node2D

@export var action_name: String = "ui_accept"  # Default action
@onready var button: Button = $Button
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Properly connect the button signals
	button.pressed.connect(_send_input_press)
	button.button_up.connect(_send_input_release)

# Optional visual feedback
func _send_input_press():
	Input.action_press(action_name)
	sprite.modulate = Color(0.8, 0.8, 0.8)  # Darken when pressed
	button.modulate = Color.WEB_GRAY
	
func _send_input_release():
	Input.action_release(action_name)
	sprite.modulate = Color.WHITE  # Return to normal
