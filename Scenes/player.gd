extends CharacterBody2D
@onready var ui: CanvasLayer = %UI

var max_speed = 100
var acceleration = 100
var direction
var friction = 500
var jump_velocity = 50.0

const MIN_JUMP_VELOCITY = 50.0
const MAX_JUMP_VELOCITY = 140.0
const JUMP_CHARGE_SPEED = 150.0

var facing = 1 # 1 = right, -1 = left
var gravity = 200
const gravity_const = 500
var jumped = false

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
#@onready var text_box: NinePatchRect = $CanvasLayer/TextBox


func _ready() -> void:
	#$Interact.body_entered.connect(interactentered)
	pass


func _physics_process(delta: float) -> void:
	
	var overlapping_bodies: Array[Node2D] = $Interact.get_overlapping_bodies()
	if overlapping_bodies.size() > 0:
		for body in overlapping_bodies:
			if body.name == "Jerald":
				if Input.is_action_just_pressed("interact"):
					ui.text = not ui.text
					print(ui.text)
					
	
	
	movement(delta)
	flipping()

	if not is_on_floor():
		velocity.y += gravity * delta


func movement(delta: float) -> void:
	if ui.text == true:
		max_speed = 0
	else:
		max_speed = 100
	direction = Input.get_axis("left", "right")
	#print($Interact.get_overlapping_bodies())a
	
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
	if is_on_floor() and Input.is_action_pressed("jump") and ui.text == false:
		player_sprite.play("Crouch")
		jump_velocity = min(
			jump_velocity + JUMP_CHARGE_SPEED * delta,
			MAX_JUMP_VELOCITY
		)
		max_speed = 30

	# Jump when releasing the button
	elif is_on_floor() and Input.is_action_just_released("jump") and ui.text == false:
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
func interactentered(body):
	print("hi")
	if Input.is_action_just_pressed("interact"):
		match body.name:
			"Jerald":
				ui.text != ui.text
			"Ant":
				ui.text != ui.text
		
			

		
	
