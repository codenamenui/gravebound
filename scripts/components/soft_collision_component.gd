# File: soft_collision_component.gd
extends Node2D
class_name SoftCollisionComponent

@export var enabled: bool = true
@export var collision_radius: float = 20.0 
@export var avoidance_strength: float = 2.0
@export var update_frequency: float = 0.1  # How often to update nearby enemies
@export var detection_radius: float = 60.0

var _parent: Node2D
var _nearby_enemies = []
var _update_timer: float = 0.0

func _ready():
	_parent = get_parent()
	if _parent is Enemy:
		# Register with the global enemy manager
		enemy_manager.register_enemy(_parent)

func _process(delta):
	if !enabled:
		return
		
	# Update nearby enemies periodically to avoid constant updates
	_update_timer -= delta
	if _update_timer <= 0:
		_update_nearby_enemies()
		_update_timer = update_frequency

func _physics_process(_delta):
	if !enabled or !_parent or !(_parent is Enemy):
		return
	
	# Update position in spatial partitioning system
	enemy_manager.update_enemy_position(_parent)

func _exit_tree():
	if _parent is Enemy:
		enemy_manager.unregister_enemy(_parent)

func _update_nearby_enemies():
	_nearby_enemies = enemy_manager.get_enemies_in_radius(_parent.global_position, detection_radius)
	# Remove self from list
	_nearby_enemies.erase(_parent)

func get_avoidance_force() -> Vector2:
	if !enabled or _nearby_enemies.size() == 0:
		return Vector2.ZERO
		
	var avoidance_force = Vector2.ZERO
	
	for other_enemy in _nearby_enemies:
		if !is_instance_valid(other_enemy) or other_enemy == _parent:
			continue
			
		var to_other = other_enemy.global_position - _parent.global_position
		var distance = to_other.length()
		
		if distance > 0 and distance < detection_radius:
			# Vector pointing away from other enemy
			var away_vec = -to_other.normalized()
			
			# Inverse square weighting - stronger when closer
			var weight = pow(1.0 - (distance / detection_radius), 2)
			
			# Add weighted avoidance vector
			avoidance_force += away_vec * weight
	
	# Normalize only if significant
	if avoidance_force.length_squared() > 0.01:
		avoidance_force = avoidance_force.normalized()
		
	return avoidance_force * avoidance_strength
