extends Node2D

var arena: Arena
var folder := "user://previews/"

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
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.current_floor = 3
	arena.cleared_challenges = 3
	for room in [1, 3, 4]:
		arena.room_states[room] = Arena.RoomState.CLEARED
	arena.dungeon.seal_room(5, false)
	arena.player.global_position = arena.dungeon.room_center(5) + Vector2(-90, 45)
	arena.player.weapon_elements[Elements.Type.METAL] = 0.35
	arena.player.weapon_elements[Elements.Type.WATER] = 0.35
	arena.player.coins = 28
	arena.player.crit_chance = 0
	arena.player.level = 4
	arena.player.experience = 9
	arena._begin_combat_room(5)
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	for index in 5:
		await get_tree().process_frame
		await get_tree().physics_frame
	var boss := get_tree().get_first_node_in_group("bosses") as DungeonBoss
	boss.set_physics_process(false)
	boss.global_position = arena.player.global_position + Vector2(120, -20)
	boss.health_component.current_health *= 0.72
	boss._start_slam()
	boss.boss_sprite.pause()
	boss.boss_sprite.frame = 0
	for hazard: Node2D in get_tree().get_nodes_in_group("enemy_attacks"):
		hazard.set_physics_process(false)
		hazard.age = 0.35
	for offset in [Vector2(35, 0), Vector2(-90, 35), Vector2(-110, -45)]:
		var enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
		enemy.data = Arena.ENEMIES[0 if offset.x > 0 else 1]
		enemy.element = Elements.Type.WOOD if offset.x > 0 else Elements.Type.FIRE
		enemy.position = arena.player.position + offset
		enemy.target = arena.player
		enemy.dungeon = arena.dungeon
		arena.actors.add_child(enemy)
		enemy.set_physics_process(false)
	arena.hud.update_inventory()
	arena.player.get_node("Camera2D").reset_smoothing()
	await get_tree().process_frame
	await get_tree().physics_frame
	arena.player.weapon_controller.current_weapon.pivot.global_rotation = 0
	arena.player.weapon_controller.current_weapon.use_weapon()
	get_tree().paused = true
	arena.hud.toast("五行附魔 · 金克木 · 寒潮巫王远程攻击预警")
	await capture("boss-combat-preview.png")
	await capture("gameplay-preview.png")
	get_tree().paused = false
	arena.hud.toast_time = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for attack in get_tree().get_nodes_in_group("enemy_attacks"):
		attack.queue_free()
	for child in get_children():
		if child is DamageNumber:
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	arena.phase = Arena.Phase.EXPLORATION
	arena.active_room = -1
	arena.current_room = 0
	for index in arena.shop_offers.size():
		arena.shop_offers[index].price = 10 + arena.current_floor * 2
	arena.player.global_position = arena.shop_service.global_position + Vector2(0, 35)
	arena.player.get_node("Camera2D").reset_smoothing()
	arena.hud.show_shop()
	await capture("shop-preview.png")
	arena.hud.hide_modal()
	arena.current_room = 2
	arena.player.global_position = arena.event_service.global_position + Vector2(0, 35)
	arena.player.get_node("Camera2D").reset_smoothing()
	arena.event_kind = 0
	arena.hud.show_event()
	await capture("event-preview.png")
	arena.hud.hide_modal()
	arena.current_room = 5
	arena.player.global_position = arena.dungeon.room_center(5)
	arena.player.get_node("Camera2D").reset_smoothing()
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.hud.show_floor_rewards()
	await capture("floor-rewards-preview.png")
	arena.hud.show_elements()
	await capture("element-choice-preview.png")
	arena.hud.hide_modal()
	arena.current_floor = 5
	arena._finish_run(true)
	await capture("result-preview.png")
	print("Saved previews: ", ProjectSettings.globalize_path(folder))
	get_tree().paused = false
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
