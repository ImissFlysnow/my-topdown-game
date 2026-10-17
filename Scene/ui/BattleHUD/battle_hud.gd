extends CanvasLayer
class_name BattleHUD

var arena: Arena
var root_control: Control
var health_bar: ProgressBar
var player_shield_bar: ProgressBar
var energy_bars: Array[ProgressBar] = []
var energy_glow_phase: float = 0.0
var energy_glow_active := false
var skill_label: Label
var active_icon: TextureRect
var passive_icon: TextureRect
var experience_bar: ProgressBar
var health_label: Label
var level_label: Label
var wave_label: Label
var status_label: Label
var coins_label: Label
var stats_label: Label
var controls_label: Label
var inventory_label: Label
var toast_label: Label
var seed_label: Label
var affix_label: Label
var boss_bar: ProgressBar
var boss_label: Label
var boss_status_label: Label
var boss_shield_bar: ProgressBar
var minimap: DungeonMinimap
var modal: ColorRect
var modal_title: Label
var modal_summary: Label
var resume_button: Button
var dialog_mode: String = ""
var toast_time: float = 0.0
var inventory_visible := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = PixelFonts.get_font(12)
	theme.default_font_size = 12
	root_control.theme = theme
	add_child(root_control)
	var player_panel := _panel(root_control, Vector2(10, 10), Vector2(170, 74))
	var portrait := TextureRect.new()
	portrait.texture = arena.player.data.icon
	portrait.position = Vector2(8, 8)
	portrait.size = Vector2(30, 30)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_panel.add_child(portrait)
	level_label = _label(player_panel, "", Vector2(44, 5), 12, Color("f9e1a3"))
	health_bar = _bar(player_panel, Vector2(44, 26), Vector2(116, 11), Color("ee7e89"))
	# A transparent gold bar wraps the health bar, using the same HP scale.
	player_shield_bar = _bar(health_bar, Vector2(-2, -2), health_bar.size + Vector2(4, 4), Color("ffd45c"))
	player_shield_bar.name = "PlayerShieldOverlay"
	player_shield_bar.step = 0.001
	player_shield_bar.z_index = 1
	var shield_background := player_shield_bar.get_theme_stylebox("background") as StyleBoxFlat
	shield_background.bg_color = Color.TRANSPARENT
	shield_background.set_border_width_all(1)
	shield_background.border_color = Color("ffd45c", 0.4)
	var shield_fill := player_shield_bar.get_theme_stylebox("fill") as StyleBoxFlat
	shield_fill.bg_color = Color(1.0, 0.83, 0.36, 0.1)
	shield_fill.set_border_width_all(2)
	shield_fill.border_color = Color("ffd45c")
	player_shield_bar.hide()
	for index in Player.ENERGY_CELLS:
		var bar := _bar(player_panel, Vector2(44 + index * 40, 43), Vector2(36, 8), Color("8fcfff"))
		bar.max_value = Player.ENERGY_PER_CELL
		bar.step = 1
		energy_bars.append(bar)
	experience_bar = _bar(player_panel, Vector2(8, 62), Vector2(154, 5), Color("90d9c0"))
	health_label = _label(player_panel, "", Vector2(8, 43), 11, Color("fac1c5"))
	coins_label = _label(root_control, "", Vector2(10, 89), 12, Color("f2d399"))
	wave_label = _label(root_control, "", Vector2(-105, 10), 17, Color("f7ead3"))
	_anchor(wave_label, 0.5, 0)
	wave_label.size.x = 210
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = _label(root_control, "", Vector2(-125, 36), 10, Color("c4b9d7"))
	_anchor(status_label, 0.5, 0)
	status_label.size.x = 250
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = _bar(root_control, Vector2(-105, 58), Vector2(210, 7), Color("ee7e89"))
	_anchor(boss_bar, 0.5, 0)
	boss_label = _label(root_control, "", Vector2(-125, 69), 11, Color("f3b8b0"))
	_anchor(boss_label, 0.5, 0)
	boss_label.size.x = 250
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_status_label = _label(root_control, "", Vector2(-155, 86), 10, Color("d3d9ed"))
	_anchor(boss_status_label, 0.5, 0)
	boss_status_label.size.x = 310
	boss_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_shield_bar = _bar(root_control, Vector2(-105, 104), Vector2(210, 5), Color("9fdfff"))
	_anchor(boss_shield_bar, 0.5, 0)
	minimap = DungeonMinimap.new()
	minimap.dungeon = arena.dungeon
	minimap.player = arena.player
	minimap.arena = arena
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -140
	minimap.offset_right = -10
	minimap.offset_top = 10
	minimap.offset_bottom = 112
	seed_label = _label(root_control, "", Vector2(-140, 115), 8, Color("8f819f"))
	_anchor(seed_label, 1, 0)
	var legend := _label(root_control, "金克木 · 木克土\n土克水 · 水克火 · 火克金\n克制 ×1.5 · 弱化 ×0.65", Vector2(-140, 131), 8, Color("c8b8d4"))
	_anchor(legend, 1, 0)
	stats_label = _label(root_control, "", Vector2(10, -43), 11, Color("dbcfe5"))
	_anchor(stats_label, 0, 1)
	affix_label = _label(root_control, "", Vector2(10, -61), 10, Color("f2dca1"))
	_anchor(affix_label, 0, 1)
	controls_label = _label(root_control, "WASD 移动 · 鼠标瞄准 · 左键攻击 · Q 技能 · E 交互 · Tab 道具 · Esc 暂停", Vector2(10, -23), 10, Color("a99dbb"))
	_anchor(controls_label, 0, 1)
	inventory_label = _label(root_control, "", Vector2(10, 115), 10, Color("e8dcbf"))
	inventory_label.hide()
	toast_label = _label(root_control, "", Vector2(-245, -94), 12, Color("ffe3a0"))
	_anchor(toast_label, 0.5, 1)
	toast_label.size.x = 490
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.z_index = 20
	var skill_panel := _panel(root_control, Vector2(-180, -97), Vector2(170, 52))
	_anchor(skill_panel, 1, 1)
	active_icon = TextureRect.new()
	active_icon.texture = SkillCatalog.icon(arena.player.skills.active_id)
	active_icon.position = Vector2(4, 4)
	active_icon.size = Vector2(32, 32)
	active_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_panel.add_child(active_icon)
	passive_icon = TextureRect.new()
	passive_icon.texture = SkillCatalog.icon(arena.player.skills.passive_id)
	passive_icon.position = Vector2(137, 4)
	passive_icon.size = Vector2(28, 28)
	passive_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_panel.add_child(passive_icon)
	skill_label = _label(skill_panel, "", Vector2(39, 3), 9, Color("ddd8ef"))
	_label(skill_panel, "Q", Vector2(15, 34), 9, Color("e6d7a5"))
	_label(skill_panel, "被动", Vector2(139, 33), 8, Color("a99dbb"))
	modal = ColorRect.new()
	root_control.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.06, 0.04, 0.1, 0.83)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.hide()
	update_inventory()
	update_health(arena.player.health_component.current_health, arena.player.health_component.max_health)
	arena.player.energy_changed.connect(update_energy)
	update_energy(arena.player.energy, Player.MAX_ENERGY)

func _process(delta: float) -> void:
	var skills := arena.player.skills
	update_player_shield()
	var definition := SkillCatalog.find(skills.active_id)
	if active_icon.get_meta("skill_id", "") != skills.active_id:
		active_icon.texture = SkillCatalog.icon(skills.active_id)
		active_icon.set_meta("skill_id", skills.active_id)
	if passive_icon.get_meta("skill_id", "") != skills.passive_id:
		passive_icon.texture = SkillCatalog.icon(skills.passive_id)
		passive_icon.set_meta("skill_id", skills.passive_id)
		var passive := SkillCatalog.find(skills.passive_id)
		passive_icon.tooltip_text = "%s\n%s" % [passive.get("name", ""), passive.get("description", "")]
		passive_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	var ready := skills.cooldown <= 0 and arena.player.energy >= int(definition.get("cost", 30))
	active_icon.modulate = Color("dbf9ff") if ready else Color("62677f")
	var state := "冷却 %.1f秒" % skills.cooldown if skills.cooldown > 0 else ("Q 可释放" if ready and arena.phase == Arena.Phase.COMBAT else "战斗中释放" if ready else "能量不足")
	skill_label.text = "%s\n消耗 %d 格\n%s" % [definition.get("name", "未装备"), int(definition.get("cost", 0)) / 10, state]
	if energy_glow_active:
		energy_glow_phase = fmod(energy_glow_phase + delta * 2.5, TAU)
		_refresh_energy_styles()
	toast_time = maxf(0.0, toast_time - delta)
	toast_label.visible = toast_time > 0.0
	toast_label.offset_top = -48 if modal.visible else -94
	toast_label.offset_bottom = -30 if modal.visible else -76
	var room_name: String = DungeonGenerator.ROOM_NAMES[arena.dungeon.room_types[arena.current_room]] if arena.current_room >= 0 else "连廊"
	wave_label.text = "第 %d / %d 层 · %s" % [arena.current_floor, arena.floor_count, room_name]
	match arena.phase:
		Arena.Phase.EXPLORATION:
			status_label.text = "挑战完成 %d / 3 · %s" % [arena.cleared_challenges, "Boss 已解锁" if arena.cleared_challenges == 3 else "清怪后解锁宝箱"]
		Arena.Phase.COMBAT:
			var count := get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("spawn_markers").size()
			status_label.text = "封门战斗 · 剩余敌人 %d" % count
		Arena.Phase.FLOOR_CLEARED, Arena.Phase.REWARD:
			status_label.text = "本层完成 · 传送门选择三选一强化"
		Arena.Phase.FINISHED:
			status_label.text = "击败敌人 %d" % arena.kills
	seed_label.text = "SEED %d" % arena.dungeon.actual_seed
	var boss := get_tree().get_first_node_in_group("bosses") as DungeonBoss
	boss_bar.visible = is_instance_valid(boss)
	boss_label.visible = is_instance_valid(boss)
	boss_status_label.visible = is_instance_valid(boss)
	boss_shield_bar.visible = is_instance_valid(boss) and boss.shield_value() > 0
	if is_instance_valid(boss):
		boss_bar.max_value = boss.health_component.max_health
		boss_bar.value = boss.health_component.current_health
		boss_label.text = "%s·%s  %.0f/%.0f%s" % [Elements.title(boss.element), boss.data.enemy_name, boss_bar.value, boss_bar.max_value, " · 狂暴" if boss.enraged else ""]
		boss_label.add_theme_color_override("font_color", Elements.color(boss.element))
		boss_status_label.text = boss.status_text()
		boss_shield_bar.max_value = boss.shield_maximum()
		boss_shield_bar.value = boss.shield_value()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if arena.phase == Arena.Phase.FINISHED:
			return
		if modal.visible:
			if dialog_mode == "rewards" or dialog_mode == "elements":
				arena.defer_floor_reward()
			else:
				hide_modal()
		else:
			show_modal("已暂停", "每层三间挑战房、商店、事件和 Boss 房。", true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not event.is_echo():
		inventory_visible = not inventory_visible
		inventory_label.visible = inventory_visible
		get_viewport().set_input_as_handled()

func update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%.0f/%.0f" % [current, maximum]
	update_player_shield()

func update_player_shield() -> void:
	var player := arena.player
	var skills := player.skills
	var charm := player.item_effects
	var current := (skills.shield if skills.shield_time > 0 else 0.0) + (charm.shield if charm.shield_time > 0 else 0.0)
	player_shield_bar.max_value = player.health_component.max_health
	player_shield_bar.value = maxf(0, current)
	player_shield_bar.visible = current > 0 and not player.health_component.is_dead

func update_energy(current: int, _maximum: int) -> void:
	for index in energy_bars.size():
		energy_bars[index].value = clampi(current - index * Player.ENERGY_PER_CELL, 0, Player.ENERGY_PER_CELL)
	energy_glow_active = current >= Player.ENERGY_PER_CELL
	_refresh_energy_styles()

func _refresh_energy_styles() -> void:
	var pulse := (sin(energy_glow_phase) + 1.0) * 0.5
	for bar in energy_bars:
		var full := bar.value >= bar.max_value
		var background := bar.get_theme_stylebox("background") as StyleBoxFlat
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		background.bg_color = Color("294d69") if full else Color("241f32")
		background.set_border_width_all(1)
		background.border_color = Color("b1ebff") if full else Color("3b3349")
		background.shadow_size = 3 if full else 0
		background.shadow_color = Color(0.35, 0.75, 1.0, 0.35 + pulse * 0.25) if full else Color.TRANSPARENT
		fill.bg_color = Color("83d2ff").lerp(Color("d0f5ff"), pulse * 0.65) if full else Color("49687f")

func update_inventory() -> void:
	var player := arena.player
	level_label.text = "%s · Lv.%d" % [player.data.id, player.level]
	experience_bar.max_value = player.experience_needed()
	experience_bar.value = player.experience
	coins_label.text = "金币 %d · 击杀 %d" % [player.coins, arena.kills]
	stats_label.text = "%s | 伤害 ×%.2f  攻速 ×%.2f  移速 %.0f" % [Global.selected_weapon.weapon_name, player.damage_multiplier, 1.0 / player.cooldown_multiplier, player.data.move_speed * player.speed_multiplier]
	var affixes: PackedStringArray = []
	for element: int in player.weapon_elements:
		affixes.append("%s +%.0f%%" % [Elements.title(element), player.weapon_elements[element] * 100])
	affix_label.text = "附魔：" + ("无 · 击败 Boss 后可选择" if affixes.is_empty() else "  ".join(affixes))
	var lines: PackedStringArray = ["持有道具"]
	for item_name: String in player.inventory:
		lines.append("%s ×%d" % [item_name, player.inventory[item_name]])
	if player.inventory.is_empty():
		lines.append("暂无 · 挑战宝箱免费")
	inventory_label.text = "\n".join(lines)

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.5

func show_modal(title: String, summary: String, allow_resume: bool) -> void:
	dialog_mode = "pause" if allow_resume else "result"
	var choices: Array[Dictionary] = []
	if allow_resume:
		choices.append({"text": "继续游戏", "action": hide_modal})
	choices.append({"text": "再来一局 · 从第一层开始", "action": arena.restart_run})
	choices.append({"text": "返回角色选择", "action": arena.return_to_selection})
	_dialog(title, summary, choices, 1, false)

func show_floor_rewards() -> void:
	dialog_mode = "rewards"
	var description := "本层奖励只能选择一次；人物成长、攻速和附魔会保留到下一层。"
	var choices: Array[Dictionary] = [
		{"text": "人物成长\n\n最大生命 +3（不回血）\n基础伤害 +15%，移速 +5%", "action": arena.choose_floor_reward.bind(0)},
		{"text": "迅捷攻击\n\n攻击冷却缩短 15%\n同步加快挥砍动作", "action": arena.choose_floor_reward.bind(1)},
		{"text": "五行附魔\n\n选择金、木、水、火、土\n每击附加 35% 属性伤害", "action": show_elements}
	]
	_dialog("第 %d 层通关 · 三选一强化" % arena.current_floor, description, choices, 3, true)

func show_elements() -> void:
	dialog_mode = "elements"
	var choices: Array[Dictionary] = []
	for element in range(1, 6):
		var counter: int = Elements.COUNTERS[element]
		choices.append({"text": "%s属性\n\n克制%s\n附加 +35%%" % [Elements.title(element), Elements.title(counter)], "action": arena.choose_floor_reward.bind(2, element), "color": Elements.color(element)})
	_dialog("选择武器附魔属性", "已有附魔会保留；同属性重复选择会叠加。物理伤害不参与五行克制。", choices, 5, true)

func show_shop() -> void:
	dialog_mode = "shop"
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var panel := _panel(modal, Vector2(-300, -158), Vector2(600, 316))
	_anchor(panel, 0.5, 0.5)
	modal_title = _label(panel, "地牢商店 · 金币 %d" % arena.player.coins, Vector2(16, 12), 24, Color("ffe3a0"))
	modal_title.size = Vector2(568, 30)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_summary = _label(panel, "", Vector2(20, 49), 12, Color("ded0e8"))
	modal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_summary.text = "每层首次刷新免费，之后依次消耗 1、2、3…金币。限购数量全局累计。"
	modal_summary.size = Vector2(560, 34)
	modal_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for index in arena.shop_offers.size():
		var offer := arena.shop_offers[index]
		var item: ItemData = offer.item
		var capped := not arena.player.can_collect_item(item)
		var button := _button(panel, "", Vector2(16 + index * 190, 88), Vector2(184, 164))
		button.name = "ShopItem%d" % index
		button.disabled = offer.sold or capped or arena.player.coins < int(offer.price)
		button.pressed.connect(arena.buy_shop.bind(index))
		button.tooltip_text = item.item_name + "\n" + item.description
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.position = Vector2(10, 10)
		icon.size = Vector2(32, 32)
		var name_label := _label(button, item.item_name, Vector2(50, 10), 12, Color("fff0ca"))
		name_label.size = Vector2(124, 20)
		var limit_text := "限 %d 件 · 已有 %d" % [item.max_stacks, arena.player.item_effects.count(item.kind)] if item.max_stacks > 0 else "永久增益 · 可叠加"
		if item.kind == ItemData.Kind.EMERGENCY_BATTERY:
			limit_text = "每局限购 1 件"
		var limit_label := _label(button, limit_text, Vector2(50, 32), 10, Color("c2b7d5"))
		limit_label.size = Vector2(124, 24)
		limit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var description := _label(button, "", Vector2(10, 60), 12, Color("f3ecfa"))
		description.name = "Description"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.text = item.description
		description.size = Vector2(164, 72)
		description.add_theme_constant_override("line_spacing", 2)
		description.add_theme_constant_override("outline_size", 1)
		var status := "已售出" if offer.sold else ("已达上限" if capped else "%d 金币%s" % [offer.price, " · 不足" if arena.player.coins < int(offer.price) else ""])
		var price_label := _label(button, status, Vector2(10, 143), 12, Color("ffe3a0"))
		price_label.size = Vector2(164, 18)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if button.disabled:
			for content: Control in button.get_children():
				content.modulate = Color(0.6, 0.6, 0.6)
	var cost := arena.shop_refresh_cost()
	var refresh := _button(panel, "刷新 · 免费" if cost == 0 else "刷新 · %d 金币" % cost, Vector2(16, 270), Vector2(180, 30))
	refresh.name = "ShopRefresh"
	PixelFonts.apply(refresh, 12)
	refresh.disabled = arena.player.coins < cost
	refresh.pressed.connect(arena.refresh_shop)
	var counter := _label(panel, "本层已刷新 %d 次" % arena.shop_refreshes, Vector2(206, 279), 10, Color("c2b7d5"))
	counter.size.x = 184
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := _button(panel, "离开", Vector2(400, 270), Vector2(184, 30))
	PixelFonts.apply(close, 12)
	close.pressed.connect(hide_modal)
	modal.show()
	get_tree().paused = true

func show_event() -> void:
	dialog_mode = "event"
	var full_health := arena.player.health_component.current_health >= arena.player.health_component.max_health
	var title := ""
	var summary := ""
	var choices: Array[Dictionary] = []
	match arena.event_kind:
		0:
			title = "随机事件 · 古老祭坛"
			summary = "献祭生命换取力量，或接受祭坛庇护。事件每层只能选择一次。"
			choices = [{"text": "献祭 2 生命 · 伤害 +30%", "action": arena.resolve_event.bind(0), "disabled": arena.player.health_component.current_health <= 2}, {"text": "祈求庇护 · 恢复 2 生命", "action": arena.resolve_event.bind(1), "disabled": full_health}]
		1:
			title = "随机事件 · 神秘旅人"
			summary = "旅人有一个未知的礼物，也愿意免费分享食物。"
			choices = [{"text": "支付 8 金币 · 随机永久道具", "action": arena.resolve_event.bind(0), "disabled": arena.player.coins < 8}, {"text": "接受食物 · 恢复 1 生命", "action": arena.resolve_event.bind(1), "disabled": full_health}]
		2:
			title = "随机事件 · 五行灵泉"
			summary = "你可以疗伤，或将灵泉的力量注入武器。"
			choices = [{"text": "饮用泉水 · 恢复 3 生命", "action": arena.resolve_event.bind(0), "disabled": full_health}, {"text": "吸收灵气 · 冷却缩短 10%", "action": arena.resolve_event.bind(1)}]
	_dialog(title, summary, choices, 1, true)

func hide_modal() -> void:
	modal.hide()
	dialog_mode = ""
	get_tree().paused = false

func _dialog(title: String, summary: String, choices: Array[Dictionary], columns: int, allow_close: bool) -> void:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	var width := 580.0 if columns > 1 else 350.0
	var height := 242.0
	var panel := _panel(modal, Vector2(-width / 2, -height / 2), Vector2(width, height))
	_anchor(panel, 0.5, 0.5)
	modal_title = _label(panel, title, Vector2(14, 14), 21 if columns > 1 else 22, Color("ffe3a0"))
	modal_title.size.x = width - 28
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_summary = _label(panel, summary, Vector2(20, 54), 11, Color("ded0e8"))
	modal_summary.size = Vector2(width - 40, 42)
	modal_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button_width := (width - 32 - (columns - 1) * 8) / columns
	for index in choices.size():
		var choice := choices[index]
		var point := Vector2(16 + (index % columns) * (button_width + 8), 102 + (index / columns) * 36)
		var button := _button(panel, choice.text, point, Vector2(button_width, 91 if columns > 1 else 30))
		button.disabled = choice.get("disabled", false)
		PixelFonts.apply(button, 10)
		if choice.has("color"):
			button.add_theme_color_override("font_color", choice.color)
			button.add_theme_color_override("font_hover_color", choice.color)
			button.add_theme_color_override("font_pressed_color", choice.color)
		button.pressed.connect(choice.action)
		if choice.text == "继续游戏":
			resume_button = button
	if allow_close:
		var close := _button(panel, "返回本层探索" if dialog_mode in ["rewards", "elements"] else "离开", Vector2(width / 2 - 80, height - 38), Vector2(160, 27))
		close.pressed.connect(arena.defer_floor_reward if dialog_mode in ["rewards", "elements"] else hide_modal)
	modal.show()
	get_tree().paused = true

func _anchor(control: Control, x: float, y: float) -> void:
	control.set_anchor(SIDE_LEFT, x, true)
	control.set_anchor(SIDE_RIGHT, x, true)
	control.set_anchor(SIDE_TOP, y, true)
	control.set_anchor(SIDE_BOTTOM, y, true)

func _panel(parent_node: Node, point: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	parent_node.add_child(panel)
	panel.position = point
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.10, 0.19, 0.94)
	style.border_color = Color("74617d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(parent_node: Node, text: String, point: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	parent_node.add_child(label)
	label.position = point
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelFonts.apply(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("22182f"))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _bar(parent_node: Node, point: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	parent_node.add_child(bar)
	bar.position = point
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.step = 0.01
	var background := StyleBoxFlat.new()
	background.bg_color = Color("32273e")
	background.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.size = dimensions
	return bar

func _button(parent_node: Node, text: String, point: Vector2, dimensions: Vector2 = Vector2(180, 29)) -> Button:
	var button := Button.new()
	PixelFonts.apply(button, 10)
	parent_node.add_child(button)
	button.text = text
	button.position = point
	var style := StyleBoxFlat.new()
	style.bg_color = Color("594762")
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("83667f")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled := style.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("362d40")
	button.add_theme_stylebox_override("disabled", disabled)
	button.size = dimensions
	return button
