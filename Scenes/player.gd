extends CharacterBody2D
@onready var ui: CanvasLayer = %UI
@onready var rocket: Node2D = %Rocket

var inventory = []

var max_speed = 100
var acceleration = 100
var direction
var friction = 500
var jump_velocity = 30.0
var scraps = 0

const MIN_JUMP_VELOCITY = 50.0
const MAX_JUMP_VELOCITY = 150.0
const JUMP_CHARGE_SPEED = 200.0

var max_speed2 = 100
var facing = 1 # 1 = right, -1 = left
var gravity = 5
const gravity_const = 5
var jumped = false

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var jerald: CharacterBody2D = %Jerald

#@onready var text_box: NinePatchRect = $CanvasLayer/TextBox


func _ready() -> void:
	#$Interact.body_entered.connect(interactentered)
	pass


func _physics_process(delta: float) -> void:
	if rocket.launching == false:
		var overlapping_bodies: Array[Node2D] = $Interact.get_overlapping_bodies()
		if overlapping_bodies.size() > 0:
			for body in overlapping_bodies:
			
				if body.name == "Jerald":
					jerald.outline = true
				elif body.name != "Jerald":
					jerald.outline = false
				if Input.is_action_just_pressed("interact"):
					
					match body.name:
						"Jerald":
							ui.text = not ui.text
							ui.person = "Jerald"
							body.mode = "Following"
							
								
							#elif body.mode == "Following":
								#body.mode = "Still"
								
						"Ant":
							ui.text = not ui.text
							ui.person = "Ant"
						"MainThruster":
							if body.rocket.parts == [true,true,true]:
								body.rocket.launching = true
				#elif body.name != "Jerald":
					#jerald.outline = false
				if Input.is_action_pressed("interact"):
					match body.name:
						"RightThruster":
							if scraps > 0 and body.rocket.scraps[2] > 0:
								body.rocket.scraps[2] -= 1 
								scraps -= 1 
						"MainThruster":
							if scraps > 0 and body.rocket.scraps[1] > 0:
								body.rocket.scraps[1] -= 1 
								scraps -= 1 
						"LeftThruster":
							if scraps > 0 and body.rocket.scraps[0] > 0:
								body.rocket.scraps[0] -= 1 
								scraps -= 1 
			

	max_speed = max_speed2

	
	if rocket.launching == false:
		movement(delta)
		if not is_on_floor():
			velocity.y += gravity
			gravity + 2 * delta
		elif is_on_floor(): 
			gravity = gravity_const
	else:
		if global_position.y > -2500:
			self.global_position = rocket.main_thruster.global_position - Vector2(0,20)
		else:
			self.global_position.y = -2500
		print(global_position.y)
		$PlayerCamera.zoom = Vector2(1,1)
		$PlayerCollision.disabled = true
		self.visible = false
		$PlayerCamera.position = Vector2(0,0) + Vector2(randf_range(-3,3),randf_range(-3,3)) 
		
		$PlayerCamera.position_smoothing_enabled = false
	flipping()
	



func movement(delta: float) -> void:
	if ui.text == true:
		max_speed = 0
	else:
		max_speed = max_speed2
	direction = Input.get_axis("left", "right")
	#
	
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
		max_speed2 = 30
		if jump_velocity < MAX_JUMP_VELOCITY:
			jump_velocity = min(
				jump_velocity + JUMP_CHARGE_SPEED * delta,
				MAX_JUMP_VELOCITY
			)
		

	# Jump when releasing the button
	elif is_on_floor() and Input.is_action_just_released("jump") and ui.text == false:
		velocity.y = -jump_velocity
		jumped = true
		max_speed2 = 100
		max_speed = max_speed2

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

		
		
		
			

		
	
