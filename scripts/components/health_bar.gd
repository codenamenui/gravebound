extends Node2D
class_name HealthBar

@export var health_component: HealthComponent
@export var animation_duration: float = 0.3
@export var shake_intensity: float = 5.0
@export var flash_intensity: float = 0.8

@onready var health_bar: TextureProgressBar = $"Health Bar"
@onready var damage_bar: TextureProgressBar = $"Damage Bar"

var damage_shader: Shader
var original_position: Vector2

func _ready() -> void:
	if !health_component:
		push_error("HealthComponent not assigned to HealthBar!")
		return
	
	original_position = position
	_setup_damage_bar()
	_create_damage_shader()
	
	health_bar.min_value = 0
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.max_health
	
	damage_bar.min_value = 0
	damage_bar.max_value = health_component.max_health
	damage_bar.value = health_component.max_health
	
	health_component.health_changed.connect(_on_health_changed)
	health_component.took_damage.connect(_on_took_damage)

func _setup_damage_bar():
	if not damage_bar:
		damage_bar = TextureProgressBar.new()
		add_child(damage_bar)
		damage_bar.name = "Damage Bar"
	
	damage_bar.texture_progress = health_bar.texture_progress
	damage_bar.texture_under = health_bar.texture_under
	damage_bar.texture_over = health_bar.texture_over
	damage_bar.size = health_bar.size
	damage_bar.position = health_bar.position
	damage_bar.modulate = Color(1.0, 0.3, 0.3, 0.8)
	
	move_child(damage_bar, 0)

func _create_damage_shader():
	damage_shader = Shader.new()
	damage_shader.code = """
shader_type canvas_item;

uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.2, 0.2);
uniform float shake_offset_x : hint_range(-10.0, 10.0) = 0.0;
uniform float shake_offset_y : hint_range(-10.0, 10.0) = 0.0;

void fragment() {
	vec2 shake_uv = UV + vec2(shake_offset_x, shake_offset_y) * 0.01;
	vec4 tex_color = texture(TEXTURE, shake_uv);
	
	vec3 final_color = mix(tex_color.rgb, flash_color, flash_intensity);
	COLOR = vec4(final_color, tex_color.a);
}
"""

func _on_health_changed(new_health: int) -> void:
	var health_tween = create_tween()
	health_tween.tween_property(health_bar, "value", new_health, animation_duration)
	
	var damage_tween = create_tween()
	damage_tween.tween_interval(0.1)
	damage_tween.tween_property(damage_bar, "value", new_health, animation_duration * 2)

func _on_took_damage(damage: int, knockback: Vector2):
	_play_damage_animation()
	_shake_health_bar()

func _play_damage_animation():
	var shader_material = ShaderMaterial.new()
	shader_material.shader = damage_shader
	health_bar.material = shader_material
	
	var flash_tween = create_tween()
	flash_tween.tween_method(_update_flash_intensity, 0.0, flash_intensity, 0.1)
	flash_tween.tween_method(_update_flash_intensity, flash_intensity, 0.0, 0.2)
	flash_tween.finished.connect(_on_damage_animation_finished)

func _shake_health_bar():
	var shake_tween = create_tween()
	
	for i in range(8):
		var shake_x = randf_range(-shake_intensity, shake_intensity)
		var shake_y = randf_range(-shake_intensity, shake_intensity)
		var shake_pos = original_position + Vector2(shake_x, shake_y)
		shake_tween.tween_property(self, "position", shake_pos, 0.05)
	
	shake_tween.tween_property(self, "position", original_position, 0.1)

func _update_flash_intensity(intensity: float):
	if health_bar.material and health_bar.material is ShaderMaterial:
		health_bar.material.set_shader_parameter("flash_intensity", intensity)

func _on_damage_animation_finished():
	health_bar.material = null

func update_max_health(new_max_health: int):
	health_bar.max_value = new_max_health
	damage_bar.max_value = new_max_health
	
	var health_tween = create_tween()
	health_tween.set_parallel(true)
	health_tween.tween_property(health_bar, "value", health_component.current_health, 0.2)
	health_tween.tween_property(damage_bar, "value", health_component.current_health, 0.3)

func pulse_heal_effect():
	var heal_tween = create_tween()
	heal_tween.tween_property(health_bar, "modulate", Color(0.5, 1.0, 0.5), 0.2)
	heal_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.3)
