class_name EnemyDebugDraw
extends Node2D

var detection_area: Area2D
var attack_area: Area2D

func _draw():
	# Draw detection range
	if is_instance_valid(detection_area) and detection_area.has_node("CollisionShape2D"):
		var detection_collision = detection_area.get_node("CollisionShape2D")
		if detection_collision.shape != null:
			draw_collision_shape(detection_collision, Color(0, 1, 0, 0.2), Color(0, 1, 0, 0.5))
	
	# Draw attack range
	if is_instance_valid(attack_area) and attack_area.has_node("CollisionShape2D"):
		var attack_collision = attack_area.get_node("CollisionShape2D")
		if attack_collision.shape != null:
			draw_collision_shape(attack_collision, Color(1, 0, 0, 0.2), Color(1, 0, 0, 0.5))

func draw_collision_shape(collision: CollisionShape2D, fill_color: Color, outline_color: Color):
	var shape = collision.shape
	var transform = collision.transform
	
	if shape is CircleShape2D:
		var radius = shape.radius
		# Adjust radius based on scale
		radius *= max(transform.get_scale().x, transform.get_scale().y)
		var center = transform.get_origin()
		
		# Draw filled circle
		draw_circle(center, radius, fill_color)
		# Draw outline
		draw_arc(center, radius, 0, TAU, 32, outline_color, 2.0)
		
	elif shape is RectangleShape2D:
		var size = shape.size
		# Adjust size based on scale
		size.x *= transform.get_scale().x
		size.y *= transform.get_scale().y
		var origin = transform.get_origin() - size/2
		var rect = Rect2(origin, size)
		
		# Draw filled rectangle
		draw_rect(rect, fill_color, true)
		# Draw outline
		draw_rect(rect, outline_color, false, 2.0)
		
	elif shape is CapsuleShape2D:
		var radius = shape.radius
		var height = shape.height
		var center = transform.get_origin()
		
		# Draw capsule (simplified as a circle for now)
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0, TAU, 32, outline_color, 2.0)
