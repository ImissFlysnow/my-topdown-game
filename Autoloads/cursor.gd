extends CanvasLayer

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
func _process(delta: float) -> void:
	sprite.position = get_viewport().get_mouse_position()
