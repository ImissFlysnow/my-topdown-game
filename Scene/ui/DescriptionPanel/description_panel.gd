extends Control
class_name DescriptionPanel

@onready var label: Label = %Label

func _ready() -> void:
	# LabelSettings takes priority over theme overrides; replace the Latin-only font.
	label.label_settings = null
	PixelFonts.apply(label, 12)

func set_text(value:String) -> void:
	label.text = value
