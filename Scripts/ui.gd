extends CanvasLayer
@onready var text_box: NinePatchRect = $"Text Box"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		text_box.visible = not text_box.visible
		print("hi")
