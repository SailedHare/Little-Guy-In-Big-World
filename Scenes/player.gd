extends CharacterBody2D
var max_speed = 100
var acceleration = 200
var direction
var friction = 500
var jump_velocity = 100
const jump_velo_const = 100
var facing = 1 #1 = right -1 = left
var gravity = 1
const gravity_const = 5
var jumped = false

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite



func _physics_process(delta: float) -> void:
	print(jump_velocity)
	movement(delta)
	flipping()
	if not is_on_floor():
		velocity.y += gravity
		gravity + 2 * delta
	else: 
		gravity = gravity_const
		

func flipping():
	if velocity.x < 0:
		facing = -1
	elif velocity.x > 0:
		facing = 1
	
	match facing:
		1:
			player_sprite.flip_h = false
		-1:
			player_sprite.flip_h = true
func movement(delta):
	direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * max_speed, acceleration * delta)
	else: 
		velocity.x = move_toward(velocity.x, 0 , friction * delta)
		
	if Input.is_action_just_released("jump") and is_on_floor():
		velocity.y = -jump_velocity
		jump_velocity = jump_velo_const
		max_speed = 100
		jumped = true
		

	if Input.is_action_pressed("jump"):
		player_sprite.play("Crouch")
		if jump_velocity < 150:
			print("hi")
			jump_velocity += 50 * delta
		max_speed = 30
	elif velocity.x != 0:
		player_sprite.play("Walk")
	elif is_on_floor() and jumped == false:
		player_sprite.play("Idle" )
	
	
	move_and_slide()
	if jumped == true and is_on_floor():
		player_sprite.play("Splat")
		if player_sprite.frame == 3:
			jumped = false
