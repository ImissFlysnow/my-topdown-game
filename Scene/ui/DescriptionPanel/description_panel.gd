extends Control
class_name DescriptionPanel

@onready var label: Label = %Label

func set_text(value:String) -> void:
	label.text = value
