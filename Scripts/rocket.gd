extends Node2D
var launching = false
var parts = [false,false,false]
var scraps = [50, 200, 50]
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#pass # Replace with function body.
#
#
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match launching:
		true:
			$RightThruster/FireParticles.emitting = true
			$LeftThruster/FireParticles.emitting = true
			$MainThruster/FireParticles.emitting = true
			$LeftThruster.collision_layer = 1
			$RightThruster.collision_layer = 1
			$MainThruster.collision_layer = 1
			$LeftThruster.freeze = false
			$RightThruster.freeze = false
			$MainThruster.freeze = false

		false:
			$RightThruster/FireParticles.emitting = false
			$LeftThruster/FireParticles.emitting = false
			$MainThruster/FireParticles.emitting = false
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
		
	
