extends Node
class_name BaseSkill

@export_group("Core Properties")
@export var skill_name: String
@export var icon: Texture2D
@export var description: String
@export var animation_name: String
@export var animation_speed: float

@export_group("Timing")
@export var cooldown_time: float
@export var anticipation_time: float
@export var contact_time: float
@export var recovery_time: float
@export var hitbox_lifetime: float
@export var hitbox_delay: float

@export_group("Movement")
@export var speed_multiplier: float = 1.0
@export var anticipation_impulse: Vector2 = Vector2.ZERO
@export var contact_impulse: Vector2 = Vector2.ZERO
@export_enum("Override", "Add To Input", "Player Control") var movement_control_mode: int = 0
@export var can_change_direction_during_skill: bool = false

@export_group("Combat")
@export var base_damage: float
@export var knockback_force: float = 300
@export var hit_stop_time: float
@export var zoom_amount: float = 1.0
@export var zoom_duration: float = 0.0

@export_group("Hitbox")
@export var hitbox_offset: Vector2 = Vector2(15, 0)
@export var hitbox_scale: Vector2 = Vector2(1, 1)

@export_group("Sprite")
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: Vector2 = Vector2(1, 1)

@export_group("SFX")
@export var sfx_name: String

@export_group("Debug")
@export var display_hitbox: bool = false
@export var hitbox_color: Color = Color(1, 0, 0, 0.5)

@export_group("Projectile")
@export var is_projectile: bool = false
@export var projectile_speed: float = 500.0
@export var projectile_distance: float = 0.0
@export var projectile_scale: Vector2 = Vector2(1, 1)
@export var projectile_pierce_count: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

var is_on_cooldown: bool = false
var is_on_anticipation: bool = false
var is_on_contact: bool = false
var is_on_recovery: bool = false
var owner_node: CharacterBody2D = null
var last_use_direction: Vector2 = Vector2.ZERO
var applied_anticipation_impulse: bool = false
var applied_contact_impulse: bool = false
var original_input_state: bool = false
var active_attacks: Array = []
var camera: Camera2D

var cooldown_timer: Timer
var anticipation_timer: Timer
var contact_timer: Timer
var recovery_timer: Timer

signal skill_ready
signal skill_started
signal skill_contact_phase
signal skill_finished
signal skill_hit_enemy(enemy)
signal skill_interrupted

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
		
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.collision_mask = 0b00000000000011
	
func _physics_process(delta):
	if !is_skill_active():
		return

	if not is_projectile and hitbox and hitbox.monitoring:
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

	for i in range(active_attacks.size() - 1, -1, -1):
		var attack = active_attacks[i]
		attack.update(delta)

func handle_override_movement():
	if !is_skill_active():
		return

	if (is_on_anticipation and applied_anticipation_impulse) or \
	   (is_on_contact and applied_contact_impulse):
		return
		
	if movement_control_mode == 0:
		owner_node.velocity = Vector2.ZERO

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

	if not is_projectile:
		_update_hitbox_orientation(direction)

	if owner_node.get_node("CharacterSpriteComponent").has_method("play_animation"):
		owner_node.get_node("CharacterSpriteComponent").play_animation(animation_name, animation_speed)

	if sfx_name != null:
		AudioManager.play_sfx(sfx_name, 0.3)

	owner_node.speed_multiplier = speed_multiplier

	emit_signal("skill_started")
	return true

func interrupt() -> void:
	if !is_skill_active():
		return

	if anticipation_timer:
		anticipation_timer.stop()
	if contact_timer:
		contact_timer.stop()
	if recovery_timer:
		recovery_timer.stop()

	is_on_anticipation = false
	is_on_contact = false
	is_on_recovery = false
	applied_anticipation_impulse = false
	applied_contact_impulse = false

	owner_node.speed_multiplier = 1.0
	owner_node.is_attacking = false
	owner_node.current_skill = null

	if movement_control_mode == 0 and original_input_state:
		owner_node.set_process_input(true)

	emit_signal("skill_interrupted")

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

func _on_anticipation_timeout() -> void:
	is_on_anticipation = false
	is_on_contact = true

	_create_attack_hitbox()

	emit_signal("skill_contact_phase")
	contact_timer.start(contact_time)

func _on_contact_timeout() -> void:
	is_on_contact = false
	is_on_recovery = true

	recovery_timer.start(recovery_time)

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

func _create_attack_hitbox() -> void:
	var spawn_pos = owner_node.global_position
	var offset = hitbox_offset.rotated(last_use_direction.angle())
	spawn_pos += offset

	var attack = await Attack.new(self, owner_node, spawn_pos, last_use_direction, is_projectile, hitbox_delay, hitbox_lifetime)
	active_attacks.append(attack)

func _update_hitbox_orientation(direction: Vector2) -> void:
	if not hitbox:
		return

	var angle = direction.angle()
	var collision_shape = hitbox.get_node_or_null("CollisionShape2D")
	if collision_shape:
		collision_shape.rotation = 0
		
func _handle_hit(target) -> void:
	if owner_node is Player:
		if target.has_method("take_damage") and target.is_in_group("Enemy"):
			var damage = get_current_damage()
			var knockback_direction = (target.global_position - owner_node.global_position).normalized()
			var knockback = knockback_direction * knockback_force
			
			target.take_damage(damage, knockback)
			
			if not is_projectile:
				camera.apply_attack_effect(zoom_amount, zoom_duration, hit_stop_time)
	else:
		if target.has_method("take_damage") and target.is_in_group("Player"):
			var damage = get_current_damage()
			
			target.take_damage(damage)

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

class Attack:
	var skill_owner: BaseSkill
	var parent_node: Node
	var direction: Vector2
	var speed: float
	var max_distance: float
	var damage: float
	var knockback_force: float
	var pierce_count: int 
	var hit_targets: Array = []
	var start_position: Vector2
	var traveled_distance: float = 0.0
	var hitbox: Area2D
	var sprite: AnimatedSprite2D
	var is_projectile: bool
	var hitbox_timer: Timer
	
	func _init(skill_owner: BaseSkill, parent_node: Node, start_position: Vector2,
			   direction: Vector2, is_projectile: bool, hitbox_delay: float, hitbox_lifetime: float):
		self.skill_owner = skill_owner
		self.parent_node = parent_node
		self.start_position = start_position
		self.direction = direction.normalized()
		self.speed = skill_owner.projectile_speed
		self.max_distance = skill_owner.projectile_distance
		self.damage = skill_owner.get_current_damage()
		self.knockback_force = skill_owner.knockback_force
		self.pierce_count = skill_owner.projectile_pierce_count
		self.is_projectile = is_projectile
		
		self.hitbox = skill_owner.hitbox.duplicate()
		if is_instance_valid(self.hitbox):
			self.hitbox.global_position = start_position
			self.hitbox.body_entered.connect(_on_hitbox_body_entered)
			self.hitbox.area_entered.connect(_on_hitbox_area_entered)
			parent_node.add_child(self.hitbox)
		
		self.sprite = skill_owner.sprite.duplicate()
		if is_instance_valid(self.sprite):
			# Apply sprite offset and scale
			var sprite_offset_rotated = skill_owner.sprite_offset.rotated(direction.angle())
			self.sprite.global_position = start_position + sprite_offset_rotated
			self.sprite.scale = skill_owner.sprite_scale
			self.sprite.play("default")
			parent_node.add_child(self.sprite)
		
		self.hitbox_timer = Timer.new()
		self.hitbox_timer.one_shot = true
		self.hitbox_timer.connect("timeout", _on_hitbox_timeout)
		parent_node.add_child(self.hitbox_timer)
		
		update_orientation(self.direction)
		
		await parent_node.get_tree().create_timer(hitbox_delay).timeout
		if is_instance_valid(self.hitbox):
			self.hitbox.monitoring = true
			self.hitbox.monitorable = true
			self.hitbox.set_as_top_level(true)
		
		self.hitbox_timer.start(hitbox_lifetime)
		skill_owner._show_hitbox_visualization(self.hitbox)

	func update(delta: float) -> void:
		if (max_distance > 0 and traveled_distance >= max_distance):
			return
		
		var movement := direction * speed * delta
		
		if is_instance_valid(hitbox):
			hitbox.global_position += movement
		
		if is_instance_valid(sprite):
			# Update sprite position with offset
			var sprite_offset_rotated = skill_owner.sprite_offset.rotated(direction.angle())
			sprite.global_position = (hitbox.global_position if is_instance_valid(hitbox) else start_position) + sprite_offset_rotated
		
		traveled_distance += movement.length()

	func update_orientation(facing_direction: Vector2) -> void:
		if is_instance_valid(hitbox):
			hitbox.rotation = facing_direction.angle()
		
		if is_instance_valid(sprite):
			sprite.rotation = facing_direction.angle()
			sprite.flip_h = false
			sprite.flip_v = false
			# Use the sprite scale from the skill owner instead of projectile scale
			sprite.scale = skill_owner.sprite_scale

	func _on_hitbox_body_entered(body) -> void:
		skill_owner._handle_hit(body)

	func _on_hitbox_area_entered(area) -> void:
		if area.get_parent() and area.name.begins_with("Hurtbox"):
			skill_owner._handle_hit(area.get_parent())

	func _on_hitbox_timeout() -> void:
		expire()

	func expire() -> void:
		if is_instance_valid(skill_owner):
			skill_owner._hide_hitbox_visualization(hitbox)
		
		if is_instance_valid(skill_owner):
			var index = skill_owner.active_attacks.find(self)
			if index != -1:
				skill_owner.active_attacks.remove_at(index)
		
		if is_instance_valid(hitbox):
			hitbox.queue_free()
		if is_instance_valid(sprite):
			sprite.queue_free()
		if is_instance_valid(hitbox_timer):
			hitbox_timer.queue_free()
