extends Control
class_name SkillTree

signal confirmed
const PANEL = preload("res://Assets/Skills/tree_panel.png")
const IDLE = preload("res://Assets/Skills/node_idle.png")
const SELECTED = preload("res://Assets/Skills/node_selected.png")
var character: PlayerData
var active_id := ""
var passive_id := ""
var buttons: Dictionary[String, Button] = {}
var content: Control
var summary: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme_value := Theme.new()
	theme_value.default_font = PixelFonts.get_font(12)
	theme_value.default_font_size = 12
	theme = theme_value
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.035, 0.075, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.offset_left = -300
	content.offset_top = -176
	content.offset_right = 300
	content.offset_bottom = 176
	var panel := NinePatchRect.new()
	panel.texture = PANEL
	panel.patch_margin_left = 6
	panel.patch_margin_right = 6
	panel.patch_margin_top = 6
	panel.patch_margin_bottom = 6
	panel.size = content.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(panel)
	for y in [72, 206]:
		var branch := Line2D.new()
		branch.points = PackedVector2Array([Vector2(108, y), Vector2(484, y)])
		branch.width = 2
		branch.default_color = Color("4d5274")
		content.add_child(branch)
		for index in 3:
			var twig := Line2D.new()
			twig.points = PackedVector2Array([Vector2(108 + index * 188, y), Vector2(108 + index * 188, y + 8)])
			twig.width = 2
			twig.default_color = Color("8b88ac")
			content.add_child(twig)
	label_at("角色技能树", Vector2(18, 7), 18, Color("eee4cc"))
	label_at("%s  ·  任选一个主动和一个被动" % SkillCatalog.TITLES.get(character.id, character.id), Vector2(18, 37), 10, Color("a3adc6"))
	var portrait := TextureRect.new()
	portrait.texture = character.icon
	portrait.position = Vector2(536, 12)
	portrait.size = Vector2(42, 42)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	label_at("主动分支  ·  Q 释放", Vector2(18, 54), 12, Color("94d6e8"))
	label_at("被动分支  ·  持续生效", Vector2(18, 188), 12, Color("d8bd85"))
	for kind in ["active", "passive"]:
		var entries := SkillCatalog.choices(character.id, kind)
		for index in entries.size():
			make_card(entries[index], Vector2(18 + index * 188, 78 if kind == "active" else 212))
	summary = label_at("", Vector2(18, 324), 10, Color("e7d9b2"))
	action_button("随机搭配", Vector2(288, 318), func(): randomize_loadout())
	action_button("返回", Vector2(388, 318), func(): hide())
	action_button("确认搭配", Vector2(488, 318), func(): commit(); confirmed.emit(); hide())
	refresh()

func label_at(value: String, point: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	PixelFonts.apply(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func style(texture: Texture2D) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_texture_margin(side, 6)
	return result

func make_card(entry: Dictionary, point: Vector2) -> void:
	var button := Button.new()
	button.position = point
	button.size = Vector2(180, 104)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = entry.name + "\n" + entry.description
	button.add_theme_stylebox_override("hover", style(SELECTED))
	button.add_theme_stylebox_override("pressed", style(SELECTED))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	content.add_child(button)
	buttons[entry.id] = button
	button.pressed.connect(func(): choose(entry.id))
	var icon := TextureRect.new()
	icon.texture = SkillCatalog.icon(entry.id)
	icon.position = Vector2(7, 6)
	icon.size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.position = Vector2(43, 6)
	PixelFonts.apply(name_label, 12)
	name_label.add_theme_color_override("font_color", Color("eee5d2"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(name_label)
	var tag := Label.new()
	tag.text = "%d 格能量 · %d秒冷却" % [int(entry.cost) / 10, entry.cooldown] if entry.kind == "active" else "被动 · 无需消耗能量"
	tag.position = Vector2(43, 25)
	PixelFonts.apply(tag, 10)
	tag.add_theme_color_override("font_color", Color("a1acc9"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tag)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = true
	PixelFonts.apply(description, 12)
	description.add_theme_constant_override("line_spacing", 2)
	description.add_theme_color_override("font_color", Color("e4e7f0"))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(description)
	description.text = entry.description
	description.position = Vector2(8, 44)
	description.size = Vector2(164, 54)

func action_button(value: String, point: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.position = point
	button.size = Vector2(92, 23)
	for state in ["normal", "hover", "pressed"]:
		var frame := style(IDLE if state == "normal" else SELECTED)
		frame.content_margin_top = 3
		frame.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, frame)
	PixelFonts.apply(button, 10)
	button.pressed.connect(action)
	content.add_child(button)

func choose(id: String) -> void:
	if SkillCatalog.valid(id, character.id, "active"):
		active_id = id
	elif SkillCatalog.valid(id, character.id, "passive"):
		passive_id = id
	refresh()
	commit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and not event.is_echo():
		hide()
		get_viewport().set_input_as_handled()

func randomize_loadout() -> void:
	active_id = SkillCatalog.choices(character.id, "active").pick_random().id
	passive_id = SkillCatalog.choices(character.id, "passive").pick_random().id
	refresh()
	commit()

func commit() -> void:
	Global.skill_loadouts[character.id] = {"active": active_id, "passive": passive_id}

func refresh() -> void:
	for id in buttons:
		var selected := id == active_id or id == passive_id
		buttons[id].add_theme_stylebox_override("normal", style(SELECTED if selected else IDLE))
	if is_instance_valid(summary):
		summary.text = "当前搭配：%s ＋ %s" % [SkillCatalog.find(active_id).get("name", "未选择"), SkillCatalog.find(passive_id).get("name", "未选择")]
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(content):
		return
	var base := content.position
	for y in [72, 206]:
		draw_line(base + Vector2(108, y), base + Vector2(484, y), Color("4d5274"), 2)
		for index in 3:
			draw_line(base + Vector2(108 + index * 188, y), base + Vector2(108 + index * 188, y + 6), Color("8b88ac"), 2)
