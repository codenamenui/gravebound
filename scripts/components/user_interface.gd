extends Control
class_name AdaptiveUI

@export var base_scale: Vector2 = Vector2.ONE
@export var scale_with_camera: bool = true
@export var maintain_aspect_ratio: bool = true

var original_scale: Vector2
var camera_ref: PlayerCamera

func _ready():
	# Add to adaptive UI group so camera can notify us
	add_to_group("adaptive_ui")
	original_scale = scale
	
	# Find the player camera
	camera_ref = get_viewport().get_camera_2d() as PlayerCamera
	if camera_ref:
		update_ui_scale(camera_ref.get_ui_scale())

func update_ui_scale(ui_scale_factor: float):
	if !scale_with_camera:
		return
		
	var new_scale = original_scale * ui_scale_factor
	
	if maintain_aspect_ratio:
		# Keep both x and y scale the same
		var uniform_scale = (new_scale.x + new_scale.y) / 2.0
		scale = Vector2(uniform_scale, uniform_scale)
	else:
		scale = new_scale

# Call this if you need to get the current UI scale programmatically
func get_current_ui_scale() -> float:
	if camera_ref:
		return camera_ref.get_ui_scale()
	return 1.0
