extends Control

var examples: Array[DungeonGenerator] = []
var font := SystemFont.new()
var folder := "user://random_map_previews/"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	for index in 5:
		var dungeon := DungeonGenerator.new()
		add_child(dungeon)
		dungeon.hide()
		dungeon.generate(2026 + index * 104729)
		examples.append(dungeon)
	queue_redraw()
	capture.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("191525"))
	draw_string(font, Vector2(16, 29), "随机地牢 · 同一局的五层布局", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe0a0"))
	draw_string(font, Vector2(16, 48), "每层六间房，五条短直走廊；保留随机布局，行走路线更清楚", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c4b9d6"))
	var gap := 9.0
	var panel_size := Vector2((size.x - 32 - gap * 2) / 3, (size.y - 72 - gap) / 2)
	var colors := [Color("cdb27d"), Color("8973b6"), Color("69b6af"), Color("c97782")]
	for index in 6:
		var origin := Vector2(16, 61) + Vector2(index % 3, index / 3) * (panel_size + Vector2.ONE * gap)
		draw_rect(Rect2(origin, panel_size), Color("272034"))
		draw_rect(Rect2(origin, panel_size), Color("645373"), false)
		if index == 5:
			draw_string(font, origin + Vector2(12, 24), "本次规则调整", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe0a0"))
			var lines := ["S 商店  C 挑战  ? 事件  B Boss", "五条直路，连接相邻房间", "房间类型、大小仍会随机变化", "Boss 生命翻倍，施法时间减半", "金币获取减半，商店价格不变", "回血仍仅限每层一次事件选择"]
			for line in lines.size():
				draw_string(font, origin + Vector2(12, 45 + line * 17), lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d8cde5"))
			continue
		var map := examples[index]
		draw_string(font, origin + Vector2(10, 19), "第 %d 层" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2dfb3"))
		var factor := minf((panel_size.x - 20) / map.grid_size.x, (panel_size.y - 35) / map.grid_size.y)
		var map_origin := origin + Vector2((panel_size.x - map.grid_size.x * factor) / 2, 27)
		for cell: Vector2i in map.floors:
			var room: int = map.floors[cell]
			var color: Color = colors[map.room_types[room]] if room < 6 else Color("665a7a")
			draw_rect(Rect2(map_origin + Vector2(cell) * factor, Vector2.ONE * maxf(1, factor)), color)
		for room in 6:
			var point := map_origin + Vector2(map.rooms[room].get_center()) * factor
			draw_string(font, point + Vector2(-3, 3), ["S", "C", "?", "B"][map.room_types[room]], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("21192c"))

func capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(folder + "five-random-floors.png")
	print("PREVIEW: five-random-floors.png result=", result)
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
