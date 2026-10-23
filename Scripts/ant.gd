extends CharacterBody2D
@onready var ant_sprite: AnimatedSprite2D = $AntSprite


var gravity = 1
var gravity_const = 5

func _physics_process(delta: float) -> void:
	

	if velocity.x != 0:
		ant_sprite.play("Walk")
	else:
		ant_sprite.play("Idle")
	
	
	if not is_on_floor():
		velocity.y += gravity
		gravity + 2 * delta
	else: 
		gravity = gravity_const
	move_and_slide()
