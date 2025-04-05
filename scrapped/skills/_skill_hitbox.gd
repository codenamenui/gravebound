extends Area2D
class_name SkillHitbox

# Hitbox properties
@export var damage: float = 10.0
@export var knockback_force: float = 100.0
@export var attack_direction: Vector2 = Vector2.ZERO
@export var hit_effect_scene: PackedScene
@export var debug_color: Color = Color(1, 0, 0, 0.5)

# References
var skill_owner: Node = null
var hit_enemies: Array = []
var debug_draw: Node2D

# Signals
signal enemy_hit(enemy)

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Set the hitbox to be in the skill_hitboxes group
	add_to_group("skill_hitboxes")
	
	# Store the skill name as metadata for cleanup
	set_meta("skill_name", get_parent().name if get_parent() != null else "unknown")
	
	# Setup debug visualization
	if Engine.is_editor_hint() or OS.is_debug_build():
		setup_debug_draw()

# Configure the hitbox with properties from the skill
func configure(config: Dictionary) -> void:
	if config.has("damage"):
		damage = config.damage
	if config.has("knockback"):
		knockback_force = config.knockback
	if config.has("owner"):
		skill_owner = config.owner

# Set the direction of the hitbox and rotate accordingly
func set_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		attack_direction = direction.normalized()
		rotation = direction.angle()

# Create the debug visualization
func setup_debug_draw() -> void:
	debug_draw = Node2D.new()
	debug_draw.script = create_debug_draw_script()
	add_child(debug_draw)
	update_debug_shapes()

# Create a script for debug drawing
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

# Update the shapes used for debug visualization
func update_debug_shapes() -> void:
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
	
	if debug_draw != null:
		debug_draw.set("shapes", shapes)
		debug_draw.set("fill_color", debug_color)
		debug_draw.queue_redraw()

# Handle enemy collision
func _on_body_entered(body) -> void:
	if body is Enemy:
		# Prevent hitting the same enemy multiple times with this hitbox
		if body in hit_enemies:
			return
			
		hit_enemies.append(body)
		
		if body.has_method("take_damage"):
			body.take_damage(damage, attack_direction)
			
			# Apply knockback if the enemy supports it
			if body.has_method("apply_knockback"):
				body.apply_knockback(attack_direction, knockback_force)
				
		# Spawn hit effect if specified
		if hit_effect_scene != null:
			var hit_effect = hit_effect_scene.instantiate()
			body.add_child(hit_effect)
			hit_effect.global_position = global_position
		
		# Emit the signal
		emit_signal("enemy_hit", body)
