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

var target: Node2D  # Player reference
var id: int
var container: EnemyContainer
var last_direction: Vector2
var is_attacking: bool = false
var speed_multiplier: float = 1.0
var current_skill

func _ready():
	skill.initialize(self)
	# Add to "enemies" group for easier management
	add_to_group("enemies")
		
	# Wait until NavigationAgent is fully initialized
	await get_tree().physics_frame
	if navigation_agent:
		navigation_agent.radius = 16
	
	state_machine.change_state(state_machine.initial_state, {})

func _physics_process(delta):
	if state_machine:
		state_machine._physics_process(delta)
	move_and_slide()
	
func _process(delta: float) -> void:
	if state_machine:
		state_machine._process(delta)
		
func _draw():
	# Debug draw path
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
	
	# Add the label as a child of the current node
	add_child(damage_label)
	
	# Set initial properties
	damage_label.modulate = Color(1, 0.3, 0.3, 1)  # Reddish color
	
	# Create a tween for animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move the label upward
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 50, 1.0)
	
	# Fade out the label
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.8)
	
	# Optional: add a slight random horizontal movement
	var random_x = randf_range(-15, 15)
	tween.tween_property(damage_label, "position:x", damage_label.position.x + random_x, 1.0)
	
	# Queue free the label after the animation
	await tween.finished
	damage_label.queue_free()
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		enemy_manager.unregister_enemy(self)
