extends Area2D

var worth = 500
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$ScrapSprite.play("default")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var overlapping_bodies: Array[Node2D] = get_overlapping_bodies()
	if overlapping_bodies.size() > 0:
		for body in overlapping_bodies:
			if body.name == "Player":
				enable_outline()
					
			
			
			if body.name == "Player" and Input.is_action_just_pressed("interact"):
				body.scraps += worth
				self.global_position = self.global_position.move_toward(body.global_position,2 * delta)
				if body.name == "Player":
					var shrink = get_tree().create_tween().parallel()
					shrink.set_ease(Tween.EaseType.EASE_IN_OUT)
					shrink.set_trans(Tween.TransitionType.TRANS_QUAD)
					shrink.tween_property($ScrapSprite, "scale",Vector2(0,0), .3)
					await shrink.finished
					queue_free()
			elif body.name != "Player":
				disable_outline()
func enable_outline():
	var material = $ScrapSprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("outline_width", 1.0)
func disable_outline():
	var material = $ScrapSprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("outline_width", 0.0)
