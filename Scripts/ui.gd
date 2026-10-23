extends CanvasLayer
@onready var text_box: NinePatchRect = $"Text Box"
var text = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	
	#if text == true and Input.is_action_just_pressed("escape"):
		#text = false
	match text:
		true:
			$"Text Box".visible = true
		false:
			$"Text Box".visible = false
			
