class_name AttackState
extends State

@export var attack_range_area_path: NodePath

var attack_range_area: Area2D
var target_in_range: bool = true

func _ready() -> void:
	enemy = get_parent().get_parent()
	# Get the attack range Area2D
	if attack_range_area_path:
		attack_range_area = get_node(attack_range_area_path)
		# Connect signals for the area
		attack_range_area.body_exited.connect(_on_attack_range_area_body_exited)

func enter(msg: Dictionary = {}) -> void:
	enemy.CharacterSprite.play_idle()
	
	# Set initial range state based on current positions if we have a target
	if enemy.target and attack_range_area:
		target_in_range = attack_range_area.overlaps_body(enemy.target)
	else:
		target_in_range = false
		
	# Connect to skill signals if not already connected
	if enemy.skill and !enemy.skill.skill_finished.is_connected(_on_skill_finished):
		enemy.skill.skill_finished.connect(_on_skill_finished)
	if enemy.skill and !enemy.skill.skill_interrupted.is_connected(_on_skill_interrupted):
		enemy.skill.skill_interrupted.connect(_on_skill_interrupted)

func exit() -> void:
	# Disconnect from skill signals when exiting the state
	if enemy.skill:
		if enemy.skill.skill_finished.is_connected(_on_skill_finished):
			enemy.skill.skill_finished.disconnect(_on_skill_finished)
		if enemy.skill.skill_interrupted.is_connected(_on_skill_interrupted):
			enemy.skill.skill_interrupted.disconnect(_on_skill_interrupted)

func physics_update(_delta: float) -> void:
	if !enemy.target:
		transition_requested.emit("ChaseState")
		return
	
	# Check if target is in range using the Area2D
	if !target_in_range:
		transition_requested.emit("ChaseState")
		return
	
	# If we have a slot in the queue, attack
	if enemy.id in enemy.container.enemy_queue:
		_attack()

func update(_delta: float) -> void:
	# Try to get a slot in the attack queue if not already in it
	if enemy.id not in enemy.container.enemy_queue:
		if enemy.container.enemy_queue.size() < 5:
			enemy.container.enemy_queue.push_back(enemy.id)

func _attack() -> void:
	if !enemy.target:
		return
	# Calculate direction to the target
	var direction = (enemy.target.global_position - enemy.global_position).normalized()
	
	# Execute the skill in the direction of the target
	if enemy.skill:
		# Execute the skill
		enemy.skill.execute(direction)

func _on_attack_range_area_body_exited(body: Node2D) -> void:
	if body == enemy.target:
		target_in_range = false

# Handle skill completion signal
func _on_skill_finished() -> void:
	enemy.container.enemy_queue.erase(enemy.id)

# Handle skill interruption signal
func _on_skill_interrupted() -> void:
	enemy.container.enemy_queue.erase(enemy.id)
