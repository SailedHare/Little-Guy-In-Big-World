extends CanvasLayer
@onready var text_box: NinePatchRect = $"Text Box"
@onready var text_label: Label = $"Text Box/Text"
@onready var player: CharacterBody2D = %Player
var credits = false
var old_scraps = 0
var text = false
var person = ""
var timer = 3
var jerald_lines = ["Glad we made it, Have you seen the other pod?", "That scared me earlier having the parachutes fail", "Lucky we survived that crash. I thought we were goners."]
var ant_lines = ["*Squeak*", "*Click* *Click*", "*Chirp*"]
var different = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Control.modulate.a = 0
	pass # Replace with function body.


func _process(delta: float) -> void:
	
	if credits == true:
		$Control.modulate.a += 1*delta
	
	
	
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
			$"Text Box/Head".play("Ant")
	$Scrapcounter/Label.text = str(player.scraps)
	$Scrapcounter/Scrap.play("default")
	if player.scraps != old_scraps:
		old_scraps = player.scraps
		different = true
	else:
		different = false
	
	match different:
		true:
			timer = 5
			ScrapIn()
		false:
			timer -= 2 * delta
			if timer < 0:
				ScrapOut()


func ScrapIn():
	var leftrighttween = get_tree().create_tween()
	leftrighttween.set_ease(Tween.EaseType.EASE_IN_OUT)
	leftrighttween.set_trans(Tween.TransitionType.TRANS_QUAD)
	leftrighttween.tween_property($Scrapcounter, "position",Vector2(168,76), .7)
	await leftrighttween.finished
	leftrighttween.kill()
	$Scrapcounter.position = Vector2(168,76)
func ScrapOut():
	
	var leftrighttween2 = get_tree().create_tween()
	leftrighttween2.set_ease(Tween.EaseType.EASE_IN_OUT)
	leftrighttween2.set_trans(Tween.TransitionType.TRANS_QUAD)
	leftrighttween2.tween_property($Scrapcounter, "position",Vector2(-100,76), .2)
	
	await leftrighttween2.finished
	leftrighttween2.kill()
	$Scrapcounter.position = Vector2(-100,76)
	
	
