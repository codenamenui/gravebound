extends Area2D

@export var speed: float = 300
@export var damage: int = 20
var direction: Vector2 = Vector2.DOWN
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Set rotation based on direction
	rotation = direction.angle()
	
	# Play fire animation
	animated_sprite.play("fire")
	
	# Start lifetime timer
	$Lifetime.start()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.name == "Walls":
		queue_free()
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
func _on_lifetime_timeout():
	queue_free()
