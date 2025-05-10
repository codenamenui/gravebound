extends CharacterBody2D
class_name Enemy

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent
@onready var state_machine: StateMachine = $StateMachine
@onready var health_component : HealthComponent = $HealthComponent
@onready var health_bar : HealthBar = $HealthBar
@onready var CharacterSprite : CharacterSpriteComponent = $CharacterSpriteComponent

var target: Node2D  # Player reference
var id: int
var container: EnemyContainer

func _ready():
	target = get_tree().current_scene.get_node("Player")
	# Wait until NavigationAgent is fully initialized
	await get_tree().physics_frame
	if navigation_agent:
		navigation_agent.avoidance_enabled = true
		navigation_agent.radius = 12.0
		navigation_agent.path_max_distance = 50.0
		
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
	state_machine.change_state($StateMachine/DamageState, {"knockback": knockback, "damage": damage})
