extends NinePatchRect
@onready var label: Label = $Label

@onready var head: AnimatedSprite2D = $Head

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	head.play("Jerald")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
