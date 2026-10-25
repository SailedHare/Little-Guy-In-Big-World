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
			$LeftThruster/CollisionShape2D.disabled = false
			$RightThruster/CollisionShape2D.disabled = false
			$MainThruster/CollisionShape2D2.disabled = false
			$MainThruster/CollisionShape2D3.disabled = false
			$LeftThruster.freeze = false
			$RightThruster.freeze = false
			$MainThruster.freeze = false

		false:
			$RightThruster/FireParticles.emitting = false
			$LeftThruster/FireParticles.emitting = false
			$MainThruster/FireParticles.emitting = false
			$LeftThruster/CollisionShape2D.disabled = true
			$RightThruster/CollisionShape2D.disabled = true
			$MainThruster/CollisionShape2D2.disabled = true
			$MainThruster/CollisionShape2D3.disabled = true
			$LeftThruster.freeze = true
			$RightThruster.freeze = true
			$MainThruster.freeze = true

			
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
	
	
