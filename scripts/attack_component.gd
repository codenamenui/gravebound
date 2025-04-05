extends Area2D
class_name AttackHitbox

var attack_direction: Vector2 = Vector2.ZERO
var debug_color = Color(1, 0, 0, 0.5)
var debug_draw: Node2D

signal attacked

func _ready():
	body_entered.connect(_on_body_entered)
	
	debug_draw = Node2D.new()
	debug_draw.script = create_debug_draw_script()
	add_child(debug_draw)
	update_debug_shapes()

func create_debug_draw_script() -> GDScript:
	var script = GDScript.new()
	script.source_code = """
extends Node2D
var shapes = []
var fill_color = Color(1, 0, 0, 0.5)
func _draw():
	for shape_data in shapes:
		if shape_data.type == "rectangle":
			draw_rect(shape_data.rect, fill_color)
		elif shape_data.type == "circle":
			draw_circle(shape_data.position, shape_data.radius, fill_color)
		elif shape_data.type == "polygon":
			draw_colored_polygon(shape_data.points, fill_color)
"""
	script.reload()
	return script

func update_debug_shapes():
	var shapes = []
	for child in get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			var shape_data = {}
			if shape is RectangleShape2D:
				shape_data = {
					"type": "rectangle",
					"rect": Rect2(-shape.size / 2 + child.position, shape.size)
				}
				shapes.append(shape_data)
			elif shape is CircleShape2D:
				shape_data = {
					"type": "circle",
					"position": child.position,
					"radius": shape.radius
				}
				shapes.append(shape_data)
			elif shape is CapsuleShape2D:
				var width = shape.radius * 2
				var height = shape.height + width
				shape_data = {
					"type": "rectangle",
					"rect": Rect2(-Vector2(width, height) / 2 + child.position, Vector2(width, height))
				}
				shapes.append(shape_data)
		elif child is CollisionPolygon2D:
			var shape_data = {
				"type": "polygon",
				"points": child.polygon
			}
			shapes.append(shape_data)
	
	debug_draw.set("shapes", shapes)
	debug_draw.set("fill_color", debug_color)
	debug_draw.queue_redraw()

func set_direction(direction: Vector2):
	if direction != Vector2.ZERO:
		attack_direction = direction.normalized()
		rotation = direction.angle()

func _on_body_entered(body):
	if body is Enemy:
		if body.has_method("take_damage"):
			emit_signal("attacked")
			body.take_damage(20, attack_direction)
