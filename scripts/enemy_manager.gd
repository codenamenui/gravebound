extends Node
class_name EnemyManager

# Grid-based spatial partitioning
var enemy_grid = {}
var grid_cell_size = 80  # Adjust based on your game scale
var registered_enemies = []

func _ready():
	# Clear the grid on ready
	enemy_grid.clear()
	registered_enemies.clear()

func register_enemy(enemy: Enemy):
	if enemy in registered_enemies:
		return
		
	registered_enemies.append(enemy)
	var cell = _get_cell_for_position(enemy.global_position)
	_add_enemy_to_cell(enemy, cell)
	enemy.set_meta("grid_cell", cell)

func unregister_enemy(enemy: Enemy):
	if !registered_enemies.has(enemy):
		return
		
	registered_enemies.erase(enemy)
	var cell = enemy.get_meta("grid_cell", Vector2i(0, 0))
	_remove_enemy_from_cell(enemy, cell)

func update_enemy_position(enemy: Enemy):
	if !registered_enemies.has(enemy):
		return
	
	var old_cell = enemy.get_meta("grid_cell", Vector2i(0, 0))
	var new_cell = _get_cell_for_position(enemy.global_position)
	
	# Only update if the cell has changed
	if old_cell != new_cell:
		_remove_enemy_from_cell(enemy, old_cell)
		_add_enemy_to_cell(enemy, new_cell)
		enemy.set_meta("grid_cell", new_cell)

func get_nearby_enemies(position: Vector2, search_radius: int = 1) -> Array:
	var center_cell = _get_cell_for_position(position)
	var result = []
	
	# Check center cell and surrounding cells based on search radius
	for x in range(-search_radius, search_radius + 1):
		for y in range(-search_radius, search_radius + 1):
			var check_cell = center_cell + Vector2i(x, y)
			if enemy_grid.has(check_cell):
				result.append_array(enemy_grid[check_cell])
	
	return result

func get_enemies_in_radius(position: Vector2, radius: float) -> Array:
	# First get all potential enemies from surrounding cells
	var search_cells = int(ceil(radius / grid_cell_size)) + 1
	var potential_enemies = get_nearby_enemies(position, search_cells)
	var result = []
	
	# Then filter by actual distance
	for enemy in potential_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(position) <= radius:
			result.append(enemy)
	
	return result

func _get_cell_for_position(position: Vector2) -> Vector2i:
	return Vector2i(
		floor(position.x / grid_cell_size),
		floor(position.y / grid_cell_size)
	)

func _add_enemy_to_cell(enemy: Enemy, cell: Vector2i) -> void:
	if !enemy_grid.has(cell):
		enemy_grid[cell] = []
	
	if !enemy_grid[cell].has(enemy):
		enemy_grid[cell].append(enemy)

func _remove_enemy_from_cell(enemy: Enemy, cell: Vector2i) -> void:
	if enemy_grid.has(cell):
		enemy_grid[cell].erase(enemy)
		
		if enemy_grid[cell].size() == 0:
			enemy_grid.erase(cell)
