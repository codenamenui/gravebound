extends State

func enter(msg : Dictionary = {}) -> void:
	enemy.CharacterSprite.play_death()
	
	# Create a timer to remove the enemy after the death animation
	var timer = Timer.new()
	enemy.add_child(timer)
	timer.wait_time = 0.3
	timer.one_shot = true
	timer.connect("timeout", _on_death_timer_timeout)
	timer.start()

# Called when the death timer completes
func _on_death_timer_timeout() -> void:
	# Remove the enemy from the scene
	enemy.queue_free()

# Called every physics frame
func update(_delta: float) -> void:
	pass

# Called when the enemy's physics process runs
func physics_update(_delta: float) -> void:
	pass
