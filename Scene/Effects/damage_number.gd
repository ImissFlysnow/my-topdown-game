extends Node2D
class_name DamageNumber

static func spawn(parent_node: Node, point: Vector2, amount: float, critical: bool = false, color: Color = Color.WHITE, prefix: String = "", suffix: String = "") -> void:
	if not is_instance_valid(parent_node):
		return
	var effect := DamageNumber.new()
	parent_node.add_child(effect)
	effect.global_position = point + Vector2(randf_range(-4, 4), 0)
	effect.z_index = 100
	var label := Label.new()
	label.text = prefix + ("%.0f" % amount if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount)
	if critical:
		label.text += "!"
	label.text += suffix
	PixelFonts.apply(label, 20 if critical else 12)
	label.add_theme_color_override("font_color", Color("ffdd76") if critical and color == Color.WHITE else color)
	label.add_theme_color_override("font_outline_color", Color("272131"))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-12, -12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_child(label)
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(effect, "position", effect.position + Vector2(randf_range(-12, 12), -32), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tween.chain().tween_callback(effect.queue_free)
