extends CharacterBody2D

var max_speed = 100
var acceleration = 100
var direction
var friction = 500
var jump_velocity = 50.0

const MIN_JUMP_VELOCITY = 50.0
const MAX_JUMP_VELOCITY = 150.0
const JUMP_CHARGE_SPEED = 150.0

var facing = 1 # 1 = right, -1 = left
var gravity = 200
const gravity_const = 500
var jumped = false

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var text_box: NinePatchRect = $CanvasLayer/TextBox


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		text_box.visible = not text_box.visible


func _physics_process(delta: float) -> void:
	movement(delta)
	flipping()

	if not is_on_floor():
		velocity.y += gravity * delta


func movement(delta: float) -> void:
	direction = Input.get_axis("left", "right")

	if direction:
		velocity.x = move_toward(
			velocity.x,
			direction * max_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0,
			friction * delta
		)

	# Charge while holding jump on the ground
	if is_on_floor() and Input.is_action_pressed("jump"):
		player_sprite.play("Crouch")
		jump_velocity = min(
			jump_velocity + JUMP_CHARGE_SPEED * delta,
			MAX_JUMP_VELOCITY
		)
		max_speed = 30

	# Jump when releasing the button
	elif is_on_floor() and Input.is_action_just_released("jump"):
		velocity.y = -jump_velocity
		jumped = true
		max_speed = 50

	elif velocity.x != 0:
		player_sprite.play("Walk")
	elif is_on_floor():
		player_sprite.play("Idle")

	# Reset charge after leaving the ground
	if not is_on_floor() and jumped:
		jump_velocity = MIN_JUMP_VELOCITY

	move_and_slide()


func flipping() -> void:
	if velocity.x < 0:
		facing = -1
	elif velocity.x > 0:
		facing = 1

	match facing:
		1:
			player_sprite.flip_h = false
		-1:
			player_sprite.flip_h = true


# AVY CAN YOU MAKE IT SO WHEN FALLING FROM A CERTAIN DISTANCE THE THING BELOW HAPPENS
# if jumped == true and is_on_floor():
#     player_sprite.play("Splat")
#     if player_sprite.frame == 3:
#         jumped = false
