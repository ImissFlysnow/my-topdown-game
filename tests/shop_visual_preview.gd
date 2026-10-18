extends Node2D

var folder := "user://shop_previews/"

func _ready() -> void:
	run.call_deferred()

func capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + filename + ".png")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	var arena := preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.skills.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.player.coins = 60
	arena.player.global_position = arena.shop_service.global_position + Vector2(0, 35)
	arena.player.get_node("Camera2D").reset_smoothing()
	arena.hud.update_inventory()
	arena.hud.toast_time = 0
	var groups := [[0, 4, 10], [1, 2, 3], [5, 6, 7], [8, 9, 10]]
	for index in groups.size():
		arena.shop_offers.clear()
		for item_index: int in groups[index]:
			var item: ItemData = ItemLoot.SKILL_PERKS[item_index]
			arena.shop_offers.append({"item": item, "price": arena.shop_price(item), "sold": false})
		arena.shop_refreshes = index
		arena.hud.show_shop()
		await capture("skill-shop-%d" % (index + 1))
		for card in arena.hud.modal.get_child(0).get_children():
			if card.name.begins_with("ShopItem"):
				var description := card.get_node("Description") as Label
				assert(description.size.x == 164 and description.get_line_count() > 1, "shop text must wrap inside each card")
				assert(description.get_line_count() * 14 <= 72, "shop text must fit vertically")
	arena.player.coins = 2
	arena.hud.show_shop()
	await capture("skill-shop-insufficient-gold")
	arena.hud.hide_modal()
	arena.player.coins = 80
	arena.player.health_component.current_health = arena.player.health_component.max_health * 0.3
	arena.hud.update_health(arena.player.health_component.current_health, arena.player.health_component.max_health)
	arena.shop_offers.clear()
	for potion: ItemData in ItemLoot.HEALING_POTIONS:
		arena.shop_offers.append({"item": potion, "price": arena.shop_price(potion), "sold": false})
	arena.hud.show_shop()
	await capture("shop-health-potions")
	arena.hud.hide_modal()
	arena.queue_free()
	await get_tree().process_frame
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	print("Saved six shop previews: ", ProjectSettings.globalize_path(folder))
	get_tree().quit()
