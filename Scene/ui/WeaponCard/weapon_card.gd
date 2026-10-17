extends TextureButton
class_name WeaponCard

@onready var icon: TextureRect = $Icon
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var selector: TextureRect = $Selector
@onready var description_panel: DescriptionPanel = $DescriptionPanel

var data:WeaponData

func  set_data(value:WeaponData) -> void:
	data = value
	icon.texture = data.icon
	set_description()

func set_description() -> void:
	var text := "武器：%s\n" % data.weapon_name
	text += "伤害：%.1f\n" % data.damage
	text += "冷却：%.1f 秒\n" % data.cooldown
	text += "消耗：%.1f\n" % data.mana_cost
	text += "散射：%.1f°\n" % data.spread

	if not data.description.is_empty():
		text += "\n\n%s" % data.description

	description_panel.set_text(text)

func _on_mouse_entered() -> void:
	hover_sound.play()
	DampedOscillator.animate(icon,"scale",randf_range(400,450),randf_range(5,10),randf_range(10,15),0.5)

	description_panel.show()
	DampedOscillator.animate(description_panel,"scale",randf_range(400,450),randf_range(5,10),randf_range(10,15),0.5)
	DampedOscillator.animate(description_panel,"rotation_degrees",300,7.5,15,0.5*randf_range(-20,-20))

func _on_mouse_exited() -> void:
	description_panel.hide()
