# state.gd (Abstract base class)
class_name State
extends Node

# Emit when wanting to transition to a new state
signal transition_requested(new_state_name: StringName)

# Reference to the enemy using this state
var enemy: CharacterBody2D

func _ready() -> void:
	enemy = get_parent().get_parent()
	print(enemy)

# Called when entering the state
func enter() -> void:
	pass

# Called when exiting the state
func exit() -> void:
	pass

# Called every physics frame
func update(_delta: float) -> void:
	pass

# Called when the enemy's physics process runs
func physics_update(_delta: float) -> void:
	pass
