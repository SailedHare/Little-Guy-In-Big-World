extends CharacterBody2D
@onready var jerald_sprite: AnimatedSprite2D = $JeraldSprite
@onready var player: CharacterBody2D = %Player
var distance_to_player = 0
var friction = 25
var max_speed = 50
var acceleration = 100
var gravity = 5 
var gravity_const = 5
var facing = 0
var range = 40
func _physics_process(delta: float) -> void:
	flipping()
	distance_to_player = self.global_position - player.global_position
	if velocity.x != 0:
		jerald_sprite.play("Walk")
	else:
		jerald_sprite.play("Idle")
	
	if distance_to_player.x > range:
		self.velocity.x = move_toward(velocity.x, -1 * max_speed,acceleration* delta )
	elif distance_to_player.x < -range:
		self.velocity.x = move_toward(velocity.x, 1 * max_speed,acceleration* delta )
	else:
		velocity.x = move_toward(velocity.x, 0 , friction * delta)
	
	
	if not is_on_floor():
		velocity.y += gravity
		gravity + 2 * delta
	elif is_on_floor(): 
		gravity = gravity_const
		
	
	if is_on_wall() and is_on_floor():
		#await get_tree().create_timer(10*delta).timeout
		velocity.y = -140
		print(velocity.y)

	move_and_slide()
	
func flipping():
	if velocity.x < 0:
		facing = -1
	elif velocity.x > 0:
		facing = 1
	
	match facing:
		1:
			jerald_sprite.flip_h = false
		-1:
			jerald_sprite.flip_h = true
