class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}  # Stores all child states by name

func _ready() -> void:
	# Cache all child states
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition_requested.connect(_on_state_transition_requested)
	
	# Initialize with the first state
	if initial_state:
		change_state(initial_state)

# Handles state transitions
func change_state(new_state: State) -> void:
	if not new_state:
		push_error("Tried to transition to a null state!")
		return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()

# Called when any state emits transition_requested
func _on_state_transition_requested(new_state_name: StringName) -> void:
	if states.has(new_state_name):
		change_state(states[new_state_name])
	else:
		push_error("State '%s' not found!" % new_state_name)

# Route updates to current state
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
