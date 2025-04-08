extends Node
class_name BaseSkill

@export var skill_name: String
@export var icon: Texture2D
@export var description: String
@export var cooldown_time: float
@export var anticipation_time: float
@export var contact_time: float
@export var recovery_time: float
@export var speed_multiplier: float
@export var leap_forward: float
@export var anticipation_backward_distance: float

@export var hitbox_scene: PackedScene
@export var hitbox_duration: float
@export var hitbox_delay: float
@export var hitbox_offset: Vector2

@export var skill_sfx: AudioStream
@export var skill_vfx_scene: PackedScene

@export var base_damage: float
@export var knockback_force: float
@export var hit_stop_time: float
@export var zoom_amount: float

# Replace these animation exports with frame range exports
@export var animation_name: String  # Keep one animation name
@export var anticipation_frames: Vector2i  # Start and end frames for anticipation phase
@export var contact_frames: Vector2i  # Start and end frames for contact phase
@export var recovery_frames: Vector2i  # Start and end frames for recovery phase

var is_on_cooldown: bool = false
var is_on_anticipation: bool = false
var is_on_contact: bool = false
var is_on_recovery: bool = false
var owner_node: CharacterBody2D = null
var last_use_direction: Vector2 = Vector2.ZERO
var active_hitboxes: Array[Node] = []

var cooldown_timer: Timer
var anticipation_timer: Timer
var contact_timer: Timer
var recovery_timer: Timer
var hitbox_timer: Timer

signal skill_ready
signal skill_started
signal skill_contact_phase
signal skill_finished
signal skill_hit_enemy(enemy)

func _init():
	pass

func initialize(skill_owner: Node) -> void:
	owner_node = skill_owner
	
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.name = skill_name + "_CooldownTimer"
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	
	anticipation_timer = Timer.new()
	anticipation_timer.one_shot = true
	anticipation_timer.name = skill_name + "_AnticipationTimer"
	anticipation_timer.timeout.connect(_on_anticipation_timeout)
	
	contact_timer = Timer.new()
	contact_timer.one_shot = true
	contact_timer.name = skill_name + "_ContactTimer"
	contact_timer.timeout.connect(_on_contact_timeout)
	
	recovery_timer = Timer.new()
	recovery_timer.one_shot = true
	recovery_timer.name = skill_name + "_RecoveryTimer"
	recovery_timer.timeout.connect(_on_recovery_timeout)
	
	hitbox_timer = Timer.new()
	hitbox_timer.one_shot = true
	hitbox_timer.name = skill_name + "_HitboxTimer"
	hitbox_timer.timeout.connect(_on_hitbox_timeout)
	
	owner_node.add_child(cooldown_timer)
	owner_node.add_child(anticipation_timer)
	owner_node.add_child(contact_timer)
	owner_node.add_child(recovery_timer)
	owner_node.add_child(hitbox_timer)

func _physics_process(delta):
	if is_on_anticipation:
		_apply_anticipation_movement(delta)
	elif is_on_contact:
		_apply_contact_movement(delta)

func execute(direction: Vector2) -> bool:
	if is_on_cooldown or is_on_anticipation or is_on_contact or is_on_recovery:
		return false
	
	last_use_direction = direction.normalized()
	is_on_anticipation = true
	
	anticipation_timer.start(anticipation_time)
	cooldown_timer.start(cooldown_time)
	
	if owner_node.get_node("CharacterSpriteComponent").has_method("play_animation_frames") 	:
		var frame_count = anticipation_frames.y - anticipation_frames.x + 1
		var speed = frame_count / anticipation_time if anticipation_time > 0 else 1.0
		owner_node.get_node("CharacterSpriteComponent").play_animation_frames(animation_name, anticipation_frames.x, anticipation_frames.y, speed)
	
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

func _apply_anticipation_movement(delta):
	if anticipation_backward_distance > 0:
		var backward_motion = -last_use_direction * anticipation_backward_distance * delta
		if owner_node.has_method("apply_external_force"):
			owner_node.apply_external_force(backward_motion)
		else:
			owner_node.velocity += backward_motion
			owner_node.move_and_slide()

func _apply_contact_movement(delta):
	if leap_forward > 0:
		var forward_motion = last_use_direction * leap_forward * delta
		if owner_node.has_method("apply_external_force"):
			owner_node.apply_external_force(forward_motion)
		else:
			owner_node.velocity = forward_motion
			owner_node.move_and_slide()

func _on_anticipation_timeout() -> void:
	is_on_anticipation = false
	is_on_contact = true
	
	if owner_node.get_node("CharacterSpriteComponent").has_method("play_animation_frames"):
		var frame_count = contact_frames.y - contact_frames.x + 1
		var speed = frame_count / contact_time if contact_time > 0 else 1.0
		owner_node.get_node("CharacterSpriteComponent").play_animation_frames(animation_name, contact_frames.x, contact_frames.y, speed)
	
	if hitbox_scene != null:
		_spawn_hitbox()
	
	emit_signal("skill_contact_phase")
	contact_timer.start(contact_time)

func _on_contact_timeout() -> void:
	is_on_contact = false
	is_on_recovery = true
	
	if owner_node.get_node("CharacterSpriteComponent").has_method("play_animation_frames"):
		var frame_count = recovery_frames.y - recovery_frames.x + 1
		var speed = frame_count / recovery_time if recovery_time > 0 else 1.0
		owner_node.get_node("CharacterSpriteComponent").play_animation_frames(animation_name, recovery_frames.x, recovery_frames.y, speed)
	
	recovery_timer.start(recovery_time)
	_cleanup_hitbox()

func _on_recovery_timeout() -> void:
	is_on_recovery = false
	owner_node.speed_multiplier = 1.0
	emit_signal("skill_finished")

func _on_cooldown_timeout() -> void:
	is_on_cooldown = false
	emit_signal("skill_ready")

func _on_hitbox_timeout() -> void:
	_cleanup_hitbox()

func _spawn_hitbox() -> void:
	var hitbox_instance = hitbox_scene.instantiate()
	owner_node.add_child(hitbox_instance)
	
	var offset = last_use_direction * hitbox_offset
	hitbox_instance.position = offset
	
	if hitbox_instance.has_method("set_direction"):
		hitbox_instance.set_direction(last_use_direction)
	
	if hitbox_instance.has_method("configure"):
		var config = {
			"damage": get_current_damage(),
			"knockback": knockback_force,
			"owner": owner_node
		}
		hitbox_instance.configure(config)
	
	if hitbox_instance.has_signal("enemy_hit"):
		hitbox_instance.connect("enemy_hit", _on_enemy_hit)
	
	active_hitboxes.append(hitbox_instance)
	hitbox_timer.start(hitbox_duration)

func _cleanup_hitbox() -> void:
	for hitbox in active_hitboxes:
		if is_instance_valid(hitbox):
			hitbox.queue_free()
	active_hitboxes.clear()

func _on_enemy_hit(enemy) -> void:
	emit_signal("skill_hit_enemy", enemy)
	
	if hit_stop_time > 0:
		var original_timescale = Engine.time_scale
		Engine.time_scale = 0.05
		await owner_node.get_tree().create_timer(hit_stop_time * 0.05).timeout
		Engine.time_scale = original_timescale

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
