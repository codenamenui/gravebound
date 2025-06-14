extends Sprite2D

@onready var parent: Joystick = $".."

var pressing = false

@export var maxLength = 50
var deadzone = 2

func _ready():
	deadzone = parent.deadzone
	maxLength *= parent.scale.x
	
func _process(delta):
	if pressing:
		if get_global_mouse_position().distance_to(parent.global_position) <= maxLength:
			global_position = get_global_mouse_position()
		else:
			var angle = parent.global_position.angle_to_point(get_global_mouse_position())
			global_position.x = parent.global_position.x + cos(angle)*maxLength
			global_position.y = parent.global_position.y + sin(angle)*maxLength
		calculateVector()
		parent.player.handle_movement(parent.posVector * parent.movement_strength)
	else:
		global_position = lerp(global_position, parent.global_position, delta*50)
		parent.posVector = Vector2(0,0)
		parent.player.handle_movement(Vector2())
	
func calculateVector():
	var delta = global_position - parent.global_position
	parent.posVector = delta / maxLength

func _on_button_button_down():
	pressing = true
	
func _on_button_button_up():
	pressing = false
