extends CanvasLayer
@onready var text_box: NinePatchRect = $"Text Box"
@onready var text_label: Label = $"Text Box/Text"

var text = false
var person = ""
var jerald_lines = ["Glad we made it, Have you seen the other pod?", "That scared me earlier having the parachutes fail", "Lucky we survived that crash. I thought we were goners."]
var ant_lines = ["*Squeak*", "*Click* *Click*", "*Chirp*"]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	
	#if text == true and Input.is_action_just_pressed("escape"):
	if Input.is_action_just_pressed("escape"):
		text = false
	match text:
		true:
			$"Text Box".visible = true
		false:
			$"Text Box".visible = false
	#print(person)
	match person:
		"Jerald":
			text_label.text = jerald_lines.pick_random()
			person = ""
			$"Text Box/Head".play("Jerald")
			
		"Ant":
			text_label.text = ant_lines.pick_random()
			person = ""
	
