extends CharacterBody2D
class_name Enemy

@export var points: int = 10

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: HealthBar = $HealthBar
@onready var character_sprite: CharacterSpriteComponent = $CharacterSpriteComponent
@onready var skill_manager: SkillManagerComponent = $SkillManagerComponent
@onready var skill: BaseSkill = $Skill
@onready var soft_collision: SoftCollisionComponent = $SoftCollisionComponent
@onready var state_machine: StateMachine = $StateMachine

var target: Node2D
var id: int
var container: EnemyContainer
var last_direction: Vector2
var is_attacking: bool = false
var speed_multiplier: float = 1.0
var current_skill
var scaled_damage
var scaled_health

var base_damage: int
var base_health: int
var base_speed: float
var current_wave: int = 1
var scaled_points: int

func _ready():
	base_damage = skill.damage if skill and skill.has_method("get") and skill.get("damage") != null else 10
	base_health = health_component.max_health if health_component else 100
	base_speed = 50.0
	
	if container and container.has_method("get_current_wave"):
		current_wave = container.get_current_wave()
	
	apply_wave_scaling()
	
	skill.initialize(self)
	add_to_group("enemies")
	
	await get_tree().physics_frame
	if navigation_agent:
		navigation_agent.radius = 16
	
	state_machine.change_state(state_machine.initial_state, {})

func apply_wave_scaling():
	var damage_scale = 1.0 + (current_wave - 1) * 0.25
	var health_scale = 1.0 + (current_wave - 1) * 0.3
	var speed_scale = 1.0 + (current_wave - 1) * 0.08
	var points_scale = 1.0 + (current_wave - 1) * 0.2

	scaled_damage = int(base_damage * damage_scale)
	scaled_health = int(base_health * health_scale)
	speed_multiplier = speed_scale
	if skill:
		skill.base_damage = scaled_damage
	scaled_points = int(10 * points_scale)
	
	if health_component:
		health_component.max_health = scaled_health
		health_component.current_health = scaled_health

func _physics_process(delta):
	if state_machine:
		state_machine._physics_process(delta)
	move_and_slide()
	
func _process(delta: float) -> void:
	if state_machine:
		state_machine._process(delta)
		
func _draw():
	if Engine.is_editor_hint() && state_machine.current_state is ChaseState:
		var points = state_machine.current_state._current_path
		for i in range(points.size() - 1):
			draw_line(points[i] - global_position, points[i+1] - global_position, Color.RED, 2)
			
func take_damage(damage: int, knockback):
	if state_machine.current_state.name == "AttackState":
		skill.interrupt()
	if state_machine.current_state.name == "DyingState":
		return
	
	show_damage_number(damage)
	
	state_machine.change_state($StateMachine/DamageState, {"knockback": knockback, "damage": damage})
	
func show_damage_number(damage_amount: int) -> void:
	var damage_label = $DamageNumber.duplicate()
	damage_label.visible = true
	damage_label.text = str(damage_amount)
	
	add_child(damage_label)
	
	damage_label.modulate = Color(1, 0.3, 0.3, 1)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 50, 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.8)
	
	var random_x = randf_range(-15, 15)
	tween.tween_property(damage_label, "position:x", damage_label.position.x + random_x, 1.0)
	
	await tween.finished
	damage_label.queue_free()
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		enemy_manager.unregister_enemy(self)

func get_scaled_speed() -> float:
	return base_speed * speed_multiplier

func set_wave_number(wave: int):
	current_wave = wave
	apply_wave_scaling()
