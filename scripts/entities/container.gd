extends Node2D
class_name EnemyContainer

@onready var spawner: WaveEnemySpawner = get_node_or_null("../EnemySpawn")
var enemy_queue: Array = []

func add_score(points: int):
	spawner.add_score(points)
