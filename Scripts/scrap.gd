extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$ScrapSprite.play("default")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var overlapping_bodies: Array[Node2D] = get_overlapping_bodies()
	if overlapping_bodies.size() > 0:
		for body in overlapping_bodies:
			#print("body.name")
			if body.name == "Player" and Input.is_action_just_pressed("interact"):
				body.scraps +=1
				queue_free()
