extends Node2D

var arena: Arena
var folder := "user://item_previews/"

func _ready() -> void:
	run.call_deferred()

func capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + filename)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_pistol.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.player.coins = 36
	arena.player.global_position = arena.shop_service.global_position + Vector2(0, 35)
	arena.player.get_node("Camera2D").reset_smoothing()
	arena.hud.update_inventory()
	arena.hud.toast_time = 0
	for group_index in 2:
		arena.shop_offers.clear()
		for item_index in range(group_index * 3, group_index * 3 + 3):
			arena.shop_offers.append({"item": ItemLoot.SHOP_PERKS[item_index], "price": 12, "sold": false})
		arena.hud.show_shop()
		await capture("item-shop-%d.png" % (group_index + 1))
		arena.hud.hide_modal()
	arena.current_room = 1
	var center := arena.dungeon.room_center(1)
	arena.player.global_position = center + Vector2(0, 90)
	arena.player.get_node("Camera2D").reset_smoothing()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	for tier in 4:
		var point := center + Vector2(-75 + tier * 50, 0)
		arena._spawn_pickup(ItemLoot.make_potion(0, tier), point)
		var label := Label.new()
		label.text = "%s\n概率 %d%%" % [ItemLoot.TIER_NAMES[tier], ItemLoot.WEIGHTS[tier]]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", ItemLoot.TIER_COLORS[tier])
		label.add_theme_color_override("font_outline_color", Color("22182f"))
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = point + Vector2(-24, 16)
		label.size.x = 48
		arena.actors.add_child(label)
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.set_physics_process(false)
	arena.hud.toast("宝箱药水：永久提升属性 · 白 / 绿 / 蓝 / 紫四档")
	await capture("chest-potion-tiers.png")
	print("Saved item previews: ", ProjectSettings.globalize_path(folder))
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
