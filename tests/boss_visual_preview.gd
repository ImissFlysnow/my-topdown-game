extends Node2D

var folder := "user://boss_previews/"

func _ready() -> void:
	run.call_deferred()

func capture(filename: String) -> void:
	for child in get_children():
		if child is DamageNumber:
			child.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(folder + filename)
	print("PREVIEW: ", filename, " result=", result)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	for floor_number in range(2, 6):
		var arena := preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
		arena.map_seed = 1015
		add_child(arena)
		arena.set_physics_process(false)
		arena.player.set_physics_process(false)
		arena.player.weapon_controller.set_physics_process(false)
		arena.player.invulnerability = 999
		arena.current_floor = floor_number
		arena.current_room = 5
		arena.active_room = 5
		arena.phase = Arena.Phase.COMBAT
		arena.cleared_challenges = 3
		arena.player.global_position = arena.dungeon.room_center(5) + Vector2(-70, 50)
		arena.player.level = floor_number + 1
		arena.player.coins = 25
		arena.player.weapon_elements[Elements.Type.WOOD] = 0.35
		arena.hud.update_inventory()
		var camera := arena.player.get_node("Camera2D") as Camera2D
		camera.position_smoothing_enabled = false
		camera.position = Vector2(50, -25)
		arena._spawn_boss(arena.dungeon.room_center(5) + Vector2(65, 25 if floor_number == 5 else 0), Arena.BOSS_DATA[floor_number - 1])
		var boss := get_tree().get_first_node_in_group("bosses") as DungeonBoss
		boss.set_physics_process(false)
		match floor_number:
			2:
				var tree := boss as ThornSovereign
				tree.skill_index = 1
				tree._start_slam()
				for offset in [Vector2(-15, -75), Vector2(-55, 75)]:
					tree._spawn_servant(tree.position + offset, ThornSovereign.MINION_DATA)
				for minion: Enemy in tree.owned_minions:
					minion.set_physics_process(false)
			3:
				var mage := boss as TideArchmage
				mage.skill_index = 1
				mage._start_slam()
				mage._tick_special_state(0.76)
				mage._tick_special_state(0.01)
				for attack in get_tree().get_nodes_in_group("enemy_attacks"):
					if attack is EnemyProjectile:
						attack._physics_process(0.45)
			4:
				var assassin := boss as EmberStalker
				assassin.skill_index = 1
				assassin._start_slam()
			5:
				boss._tick_special_state(1.6)
		boss.boss_sprite.pause()
		boss.boss_sprite.frame = 1
		for attack in get_tree().get_nodes_in_group("enemy_attacks"):
			attack.set_physics_process(false)
			attack.set_process(false)
			if attack is GroundHazard or attack is BossTelegraph:
				attack.age = 0.38
		arena.hud.toast_time = 0
		camera.reset_smoothing()
		await get_tree().physics_frame
		await capture("%d-%s.png" % [floor_number, boss.name])
		if floor_number == 5:
			var warden := boss as BastionWarden
			boss.take_hit(9999)
			await get_tree().process_frame
			await capture("5-warden-vulnerable.png")
			warden._tick_special_state(1.01)
			warden.skill_index = 1
			warden._start_slam()
			warden._physics_process(0.46)
			for attack in get_tree().get_nodes_in_group("enemy_attacks"):
				if attack is EnemyProjectile:
					attack._physics_process(0.35)
				attack.set_physics_process(false)
				attack.set_process(false)
			await capture("5-warden-exposed-counter.png")
			warden.take_hit(10)
			warden.exposed_time = 0.01
			warden._physics_process(0.02)
			await capture("5-warden-partial-repair-warning.png")
			warden._tick_special_state(0.91)
			await capture("5-warden-partial-shield.png")
			warden.take_hit(99999)
			boss.take_hit(99999)
			boss.state_time = 0.45
			boss.queue_redraw()
			await capture("5-warden-reforge.png")
			boss._tick_special_state(0.46)
			boss.take_hit(99999)
			warden.skill_index = 2
			boss._start_slam()
			for attack in get_tree().get_nodes_in_group("enemy_attacks"):
				attack.set_physics_process(false)
				attack.set_process(false)
				if attack is GroundHazard or attack is BossTelegraph:
					attack.age = 0.25
			await capture("5-warden-cross-quake.png")
			boss._clear_owned_attacks()
			await get_tree().process_frame
			boss.health_component.current_health = boss.health_component.max_health * 0.4
			boss.enraged = true
			warden.skill_index = 1
			boss._start_slam()
			boss._tick_special_state(0.46)
			for attack in get_tree().get_nodes_in_group("enemy_attacks"):
				if attack is EnemyProjectile:
					attack._physics_process(0.5)
			boss._tick_special_state(0.19)
			for attack in get_tree().get_nodes_in_group("enemy_attacks"):
				if attack is EnemyProjectile:
					attack._physics_process(0.3)
			boss._tick_special_state(0.19)
			for attack in get_tree().get_nodes_in_group("enemy_attacks"):
				attack.set_physics_process(false)
				attack.set_process(false)
			await capture("5-warden-enraged-volley.png")
		arena.queue_free()
		for child in get_children():
			if child is DamageNumber:
				child.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
