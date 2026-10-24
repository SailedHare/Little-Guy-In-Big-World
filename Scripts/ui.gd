extends CanvasLayer
@onready var text_box: NinePatchRect = $"Text Box"
@onready var text_label: Label = $"Text Box/Text"
@onready var player: CharacterBody2D = %Player

var old_scraps = 0
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
			$"Text Box/Head".play("Ant")
	$Label.text = str(player.scraps)
	$Scrap.play("default")
	if player.scraps != old_scraps:
		print("hi")
		old_scraps = player.scraps
		print("")
		var leftrighttween = get_tree().create_tween().set_parallel(true)
		leftrighttween.set_ease(Tween.EaseType.EASE_IN_OUT)
		leftrighttween.set_trans(Tween.TransitionType.TRANS_QUAD)
		leftrighttween.tween_property($Scrap, "position",Vector2(82.0,56), .7)
		leftrighttween.tween_property($Label, "position",Vector2(165,50), .7)
		await get_tree().create_timer(3.0).timeout
		leftrighttween.kill()
		var leftrighttween2 = get_tree().create_tween().set_parallel(true)
		leftrighttween2.set_ease(Tween.EaseType.EASE_IN_OUT)
		leftrighttween2.set_trans(Tween.TransitionType.TRANS_QUAD)
		leftrighttween2.tween_property($Scrap, "position",Vector2(-133.0,56), .7)
		leftrighttween2.tween_property($Label, "position",Vector2(-52,50), .7)
		await leftrighttween2.finished
		leftrighttween2.kill()
		$Scrap.position = Vector2(-133,56)
		$Label.position = Vector2(-52,50)
	
