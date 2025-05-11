extends Node
class_name BaseSkill

# Core Properties
@export_group("Core Properties")
@export var skill_name: String
@export var icon: Texture2D
@export var description: String
@export var animation_name: String
@export var animation_speed: float

# Timing Properties
@export_group("Timing")
@export var cooldown_time: float
@export var anticipation_time: float
@export var contact_time: float
@export var recovery_time: float
@export var hitbox_duration: float
@export var hitbox_delay: float

# Movement Properties
@export_group("Movement")
@export var speed_multiplier: float = 1.0
@export var anticipation_impulse: Vector2 = Vector2.ZERO
@export var contact_impulse: Vector2 = Vector2.ZERO
@export_enum("Override", "Add To Input", "Player Control") var movement_control_mode: int = 0
@export var can_change_direction_during_skill: bool = false

# Combat Properties
@export_group("Combat")
@export var base_damage: float
@export var knockback_force: float = 300
@export var hit_stop_time: float
@export var zoom_amount: float = 1.0
@export var zoom_duration: float = 0.0

# Hitbox Properties
@export_group("Hitbox")
@export var hitbox_shape: Shape2D
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var hitbox_scale: Vector2 = Vector2(1, 1)

# Effect Properties
@export_group("Effects")
@export var skill_sfx: AudioStream
@export var skill_vfx_scene: PackedScene
@export var camera: PlayerCamera

# Debug Properties
@export_group("Debug")
@export var display_hitbox: bool = false
@export var hitbox_color: Color = Color(1, 0, 0, 0.5)

# State Variables
var is_on_cooldown: bool = false
var is_on_anticipation: bool = false
var is_on_contact: bool = false
var is_on_recovery: bool = false
var owner_node: CharacterBody2D = null
var last_use_direction: Vector2 = Vector2.ZERO
var applied_anticipation_impulse: bool = false
var applied_contact_impulse: bool = false
var original_input_state: bool = false

# Timers
var cooldown_timer: Timer
var anticipation_timer: Timer
var contact_timer: Timer
var recovery_timer: Timer
var hitbox_timer: Timer
var hitbox: Area2D

# Signals
signal skill_ready
signal skill_started
signal skill_contact_phase
signal skill_finished
signal skill_hit_enemy(enemy)
signal skill_interrupted

# Initialization
func _init():
	pass

func initialize(skill_owner: Node) -> void:
	owner_node = skill_owner
	
	if not get_node_or_null(skill_name + "_CooldownTimer"):
		cooldown_timer = Timer.new()
		cooldown_timer.one_shot = true
		cooldown_timer.name = skill_name + "_CooldownTimer"
		cooldown_timer.timeout.connect(_on_cooldown_timeout)
		owner_node.add_child(cooldown_timer)
	else:
		cooldown_timer = get_node(skill_name + "_CooldownTimer")

	if not get_node_or_null(skill_name + "_AnticipationTimer"):
		anticipation_timer = Timer.new()
		anticipation_timer.one_shot = true
		anticipation_timer.name = skill_name + "_AnticipationTimer"
		anticipation_timer.timeout.connect(_on_anticipation_timeout)
		owner_node.add_child(anticipation_timer)
	else:
		anticipation_timer = get_node(skill_name + "_AnticipationTimer")

	if not get_node_or_null(skill_name + "_ContactTimer"):
		contact_timer = Timer.new()
		contact_timer.one_shot = true
		contact_timer.name = skill_name + "_ContactTimer"
		contact_timer.timeout.connect(_on_contact_timeout)
		owner_node.add_child(contact_timer)
	else:
		contact_timer = get_node(skill_name + "_ContactTimer")

	if not get_node_or_null(skill_name + "_RecoveryTimer"):
		recovery_timer = Timer.new()
		recovery_timer.one_shot = true
		recovery_timer.name = skill_name + "_RecoveryTimer"
		recovery_timer.timeout.connect(_on_recovery_timeout)
		owner_node.add_child(recovery_timer)
	else:
		recovery_timer = get_node(skill_name + "_RecoveryTimer")

	if not get_node_or_null(skill_name + "_HitboxTimer"):
		hitbox_timer = Timer.new()
		hitbox_timer.one_shot = true
		hitbox_timer.name = skill_name + "_HitboxTimer"
		hitbox_timer.timeout.connect(_on_hitbox_timeout)
		owner_node.add_child(hitbox_timer)
	else:
		hitbox_timer = get_node(skill_name + "_HitboxTimer")

	create_or_get_hitbox()

# Main Process Functions
func _physics_process(delta):
	if !is_skill_active():
		return

	if hitbox and hitbox.monitoring:
		var player_facing_angle = last_use_direction.angle()
		var rotated_offset = hitbox_offset.rotated(player_facing_angle)
		hitbox.global_position = owner_node.global_position + rotated_offset
		hitbox.rotation = player_facing_angle
	
	if is_on_anticipation and not applied_anticipation_impulse:
		_apply_anticipation_impulse()
	elif is_on_contact and not applied_contact_impulse:
		_apply_contact_impulse()
	
	if movement_control_mode == 0:
		handle_override_movement()

func handle_override_movement():
	if !is_skill_active():
		return

	if (is_on_anticipation and applied_anticipation_impulse) or \
	   (is_on_contact and applied_contact_impulse):
		return
		
	if movement_control_mode == 0:
		owner_node.velocity = Vector2.ZERO

# Skill Execution
func execute(direction: Vector2) -> bool:
	if is_on_cooldown or is_on_anticipation or is_on_contact or is_on_recovery:
		return false

	last_use_direction = direction.normalized()
	is_on_anticipation = true
	applied_anticipation_impulse = false
	applied_contact_impulse = false
	owner_node.is_attacking = true

	if movement_control_mode == 0:
		original_input_state = owner_node.is_processing_input()
		if original_input_state:
			owner_node.set_process_input(false)

	anticipation_timer.start(anticipation_time)
	cooldown_timer.start(cooldown_time)

	_update_hitbox_orientation(direction)

	if owner_node.get_node("CharacterSpriteComponent").has_method("play_animation"):
		owner_node.get_node("CharacterSpriteComponent").play_animation(animation_name, animation_speed)

	if skill_sfx != null:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = skill_sfx
		audio_player.one_shot = true
		owner_node.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(func(): audio_player.queue_free())

	if skill_vfx_scene != null:
		var vfx = skill_vfx_scene.instantiate()
		owner_node.add_child(vfx)
		vfx.global_position = owner_node.global_position

	owner_node.speed_multiplier = speed_multiplier

	emit_signal("skill_started")
	return true

func interrupt() -> void:
	if !is_skill_active():
		return

	if anticipation_timer and anticipation_timer.is_active():
		anticipation_timer.stop()
	if contact_timer and contact_timer.is_active():
		contact_timer.stop()
	if recovery_timer and recovery_timer.is_active():
		recovery_timer.stop()
	if hitbox_timer and hitbox_timer.is_active():
		hitbox_timer.stop()

	is_on_anticipation = false
	is_on_contact = false
	is_on_recovery = false
	applied_anticipation_impulse = false
	applied_contact_impulse = false

	_deactivate_hitbox()

	owner_node.speed_multiplier = 1.0
	owner_node.is_attacking = false
	owner_node.current_skill = null

	if movement_control_mode == 0 and original_input_state:
		owner_node.set_process_input(true)

	emit_signal("skill_interrupted")

# State Check Functions
func is_skill_active() -> bool:
	return is_on_anticipation or is_on_contact or is_on_recovery

func get_current_damage() -> float:
	return base_damage

func get_current_cooldown() -> float:
	return cooldown_time

func get_cooldown_remaining() -> float:
	if !is_on_cooldown:
		return 0.0
	return cooldown_timer.time_left

func get_info() -> Dictionary:
	return {
		"name": skill_name,
		"description": description,
		"cooldown": get_current_cooldown(),
		"damage": get_current_damage(),
		"icon": icon
	}

# Movement Functions
func _apply_anticipation_impulse():
	if anticipation_impulse.length() > 0:
		var rotated_impulse = _get_rotated_vector(anticipation_impulse)
		_apply_impulse(rotated_impulse)
		applied_anticipation_impulse = true

func _apply_contact_impulse():
	if contact_impulse.length() > 0:
		var rotated_impulse = _get_rotated_vector(contact_impulse)
		_apply_impulse(rotated_impulse)
		applied_contact_impulse = true

func _get_rotated_vector(original_vector: Vector2) -> Vector2:
	var player_facing_angle = last_use_direction.angle()
	return original_vector.rotated(player_facing_angle)

func _apply_impulse(impulse: Vector2):
	if owner_node.has_method("apply_impulse"):
		owner_node.apply_impulse(impulse)
	else:
		owner_node.velocity += impulse

# Timer Callback Functions
func _on_anticipation_timeout() -> void:
	is_on_anticipation = false
	is_on_contact = true

	if hitbox_delay > 0:
		await owner_node.get_tree().create_timer(hitbox_delay).timeout

	create_or_get_hitbox()
	_activate_hitbox()

	emit_signal("skill_contact_phase")
	contact_timer.start(contact_time)

func _on_contact_timeout() -> void:
	is_on_contact = false
	is_on_recovery = true

	recovery_timer.start(recovery_time)
	_deactivate_hitbox()

func _on_recovery_timeout() -> void:
	is_on_recovery = false
	owner_node.speed_multiplier = 1.0
	owner_node.is_attacking = false
	owner_node.current_skill = null

	if movement_control_mode == 0 and original_input_state:
		owner_node.set_process_input(true)

	emit_signal("skill_finished")

func _on_cooldown_timeout() -> void:
	is_on_cooldown = false
	emit_signal("skill_ready")

func _on_hitbox_timeout() -> void:
	_deactivate_hitbox()

# Hitbox Functions
func create_or_get_hitbox() -> void:
	hitbox = get_node_or_null("Hitbox")

	if not hitbox:
		hitbox = Area2D.new()
		hitbox.name = "Hitbox"
		hitbox.collision_layer = 4
		hitbox.collision_mask = 8
		
		var shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		
		if hitbox_shape:
			shape_node.shape = hitbox_shape
		else:
			var default_shape = CircleShape2D.new()
			default_shape.radius = 50
			shape_node.shape = default_shape
		
		shape_node.position = hitbox_offset
		shape_node.scale = hitbox_scale
		
		hitbox.add_child(shape_node)
		add_child(hitbox)

	hitbox.monitoring = false
	hitbox.monitorable = false

	if not hitbox.is_connected("body_entered", _on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if not hitbox.is_connected("area_entered", _on_hitbox_area_entered):
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _activate_hitbox() -> void:
	if not hitbox or not is_instance_valid(hitbox):
		create_or_get_hitbox()

	if hitbox:
		var player_facing_angle = last_use_direction.angle()
		var rotated_offset = hitbox_offset.rotated(player_facing_angle)
		
		hitbox.global_position = owner_node.global_position + rotated_offset
		hitbox.rotation = player_facing_angle
		
		var collision_shape = hitbox.get_node("CollisionShape2D")
		if collision_shape:
			collision_shape.position = Vector2.ZERO
			collision_shape.rotation = 0
		
		hitbox.monitoring = true
		hitbox.monitorable = true
		hitbox.set_as_top_level(true)
		
		if display_hitbox:
			_show_hitbox_visualization(hitbox)
		
		if hitbox_duration > 0:
			hitbox_timer.start(hitbox_duration)

func _deactivate_hitbox() -> void:
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		_hide_hitbox_visualization(hitbox)

func _update_hitbox_orientation(direction: Vector2) -> void:
	if not hitbox:
		return

	var angle = direction.angle()
	var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.rotation = 0

# Hitbox Visualization
func _show_hitbox_visualization(hitbox: Node) -> void:
	if not display_hitbox:
		return

	var existing_debug = hitbox.get_node_or_null("DebugDraw")
	if existing_debug:
		existing_debug.queue_free()

	var debug_draw = Node2D.new()
	debug_draw.name = "DebugDraw"
	debug_draw.z_index = 100

	var script = GDScript.new()
	script.source_code = """
extends Node2D

var color: Color
var shapes: Array = []
var custom_scale: Vector2 = Vector2.ONE

func _ready():
	for child in get_parent().get_children():
		if child is CollisionShape2D and child.shape:
			shapes.append({
				"shape": child.shape,
				"position": child.position,
				"rotation": child.rotation,
				"scale": child.scale
			})

func _process(_delta):
	queue_redraw()

func _draw():
	for shape_info in shapes:
		var shape = shape_info.shape
		var pos = shape_info.position
		var rot = shape_info.rotation
		var scl = shape_info.scale * custom_scale
		
		var transform_matrix = Transform2D().rotated(rot).scaled(scl)
		
		if shape is RectangleShape2D:
			var rect_size = shape.size
			var rect = Rect2(-rect_size/2, rect_size)
			draw_set_transform(pos, rot, scl)
			draw_rect(rect, color, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			
		elif shape is CircleShape2D:
			var radius = shape.radius
			draw_set_transform(pos, rot, scl)
			draw_circle(Vector2.ZERO, radius, color)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			
		elif shape is CapsuleShape2D:
			var radius = shape.radius
			var height = shape.height
			
			draw_set_transform(pos, rot, scl)
			
			var rect = Rect2(-radius, -height/2, radius * 2, height)
			draw_rect(rect, color, true)
			
			var top_center = Vector2(0, -height/2)
			draw_circle(top_center, radius, color)
			
			var bottom_center = Vector2(0, height/2)
			draw_circle(bottom_center, radius, color)
			
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
"""

	script.reload()
	debug_draw.set_script(script)
	debug_draw.color = hitbox_color
	hitbox.add_child(debug_draw)

func _hide_hitbox_visualization(hitbox: Node) -> void:
	var debug_draw = hitbox.get_node_or_null("DebugDraw")
	if debug_draw:
		debug_draw.queue_free()

func set_hitbox_visibility(visible: bool) -> void:
	display_hitbox = visible
	
	if is_on_contact:
		if hitbox:
			if visible:
				_show_hitbox_visualization(hitbox)
			else:
				_hide_hitbox_visualization(hitbox)

# Hit Detection Functions
func _on_hitbox_body_entered(body) -> void:
	_handle_hit(body)

func _on_hitbox_area_entered(area) -> void:
	if area.get_parent() and area.name.begins_with("Hurtbox"):
		_handle_hit(area.get_parent())

func _handle_hit(target) -> void:
	if owner_node is Player:
		if target.has_method("take_damage") and target.is_in_group("Enemy"):
			var damage = get_current_damage()
			var knockback_direction = (target.global_position - owner_node.global_position).normalized()
			var knockback = knockback_direction * knockback_force
			
			target.take_damage(damage, knockback)
			
			camera.apply_attack_effect(zoom_amount, zoom_duration, hit_stop_time)
	else:
		if target.has_method("take_damage") and target.is_in_group("Player"):
			var damage = get_current_damage()
			var knockback_direction = (target.global_position - owner_node.global_position).normalized()
			var knockback = knockback_direction * knockback_force
			
			target.take_damage(damage, knockback)
