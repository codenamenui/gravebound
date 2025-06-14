# tilemap_navigator.gd (attach to any node)
extends Node

@export var tilemap: TileMap
@export var bake_in_thread := true

func _ready():
	call_deferred("_bake_navigation")

func _bake_navigation():
	if bake_in_thread:
		# Threaded baking for large maps
		var thread = Thread.new()
		thread.start(_threaded_bake)
	else:
		_direct_bake()

func _threaded_bake():
	tilemap.bake_navigation_polygon(0)  # Layer 0
	call_deferred("_on_bake_complete")

func _direct_bake():
	tilemap.bake_navigation_polygon(0)  # Main thread (small maps only)
