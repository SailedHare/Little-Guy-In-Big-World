extends Node2D
var launching = false
var parts = [false,false,false]
var scraps = [50, 200, 50]
@onready var main_thruster: RigidBody2D = $MainThruster
var propulsion = 100
var main_propulsion = 100
var stand_pos = Vector2()
var seperated = false
## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	stand_pos = $Sprite2D.global_rotation
	#pass # Replace with function body.
#
#
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$MainThruster.global_rotation_degrees = 0
	match launching:
		true:
			if seperated == false:
				$RightThruster/FireParticles.emitting = true
				$LeftThruster/FireParticles.emitting = true
				$LeftThruster.gravity_scale -= 1 * delta
				$RightThruster.gravity_scale -= 1 * delta
				propulsion += 10 * delta
			$MainThruster/FireParticles.emitting = true
			$MainThruster/FireParticles2.emitting = true
			$LeftThruster.collision_layer = 1
			$RightThruster.collision_layer = 1
			$MainThruster.collision_layer = 1
			$LeftThruster.freeze = false
			$RightThruster.freeze = false
			$MainThruster.freeze = false
			$LeftThruster.global_position.y -= propulsion * delta
			$RightThruster.global_position.y -= propulsion * delta
			$MainThruster.global_position.y -= main_propulsion * delta
			$MainThruster.gravity_scale -= 1 * delta
			
			main_propulsion += 10 * delta
			
			await get_tree().create_timer(700 * delta).timeout
			seperated = true
			
			$LeftThruster.global_position.x -= 20 * delta
			$RightThruster.global_position.x += 20 * delta
			$RightThruster.rotation_degrees += 10 * delta
			$LeftThruster.rotation_degrees -= 10 * delta
			$RightThruster/FireParticles.emitting = false
			$LeftThruster/FireParticles.emitting = false
			$LeftThruster.gravity_scale = .8
			$RightThruster.gravity_scale = .8
			propulsion = - 100
			
		false:
			$RightThruster/FireParticles.emitting = false
			$LeftThruster/FireParticles.emitting = false
			$MainThruster/FireParticles.emitting = false
			$MainThruster/FireParticles2.emitting = false
			$LeftThruster.collision_layer = 8
			$RightThruster.collision_layer = 8
			$MainThruster.collision_layer = 8
			$LeftThruster.freeze = true
			$RightThruster.freeze = true
			$MainThruster.freeze = true
	$RightThruster/AnimatedSprite2D2/Label.text = str(scraps[2])
	$LeftThruster/AnimatedSprite2D2/Label.text = str(scraps[0])
	$MainThruster/AnimatedSprite2D2/Label.text = str(scraps[1])
	
			
	match parts[0]:
		true:
			$LeftThruster/AnimatedSprite2D.modulate.a = 1
			
		false:
			$LeftThruster/AnimatedSprite2D.modulate.a = .5
	match parts[1]:
		true:
			$MainThruster/AnimatedSprite2D.modulate.a = 1
		false:
			$MainThruster/AnimatedSprite2D.modulate.a = .5
	match parts[2]:
		true:
			$RightThruster/AnimatedSprite2D.modulate.a = 1
		false:
			$RightThruster/AnimatedSprite2D.modulate.a = .5
	
	if scraps[0] < 1:
		parts[0] = true
		$LeftThruster/AnimatedSprite2D2.visible = false
	if scraps[1] < 1:
		parts[1] = true
		$MainThruster/AnimatedSprite2D2.visible = false
	if scraps[2] < 1:
		parts[2] = true
		$RightThruster/AnimatedSprite2D2.visible = false
		
	
