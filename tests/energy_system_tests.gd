extends Node2D

var checks := 0
var failures := 0
var arena: Arena
var enemy: Enemy

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func frames(count: int = 3) -> void:
	for index in count:
		await get_tree().process_frame
		await get_tree().physics_frame

func make_enemy() -> Enemy:
	var result := Arena.ENEMY_SCENE.instantiate() as Enemy
	result.data = Arena.ENEMIES[0].duplicate() as EnemyData
	result.data.max_health = 10000
	result.data.coins = 0
	result.data.experience = 0
	result.target = arena.player
	result.position = arena.player.position + Vector2(50, 0)
	arena.actors.add_child(result)
	result.set_physics_process(false)
	return result

func reset_energy() -> void:
	arena.player.energy = 0
	arena.player._reset_energy_charge()
	arena.player.energy_changed.emit(0, Player.MAX_ENERGY)

func test_rate() -> void:
	var player := arena.player
	check(player.energy == 0 and Player.MAX_ENERGY == 30 and Player.ENERGY_PER_CELL == 10 and Player.ENERGY_REGEN_INTERVAL == 0.25, "energy starts empty with three ten-point cells and an eight-times-faster 0.25-second interval")
	enemy.take_hit(1)
	check(not player.energy_charge_started, "damage outside combat does not start regeneration")
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 1
	enemy.take_hit(1)
	check(player.energy == 0 and player.energy_charge_started, "first real hit starts a quarter-second charge instead of granting instant energy")
	player._tick_energy(Player.ENERGY_REGEN_INTERVAL - 0.01)
	enemy.take_hit(1)
	check(player.energy == 0, "hits before the quarter-second interval cannot grant energy")
	player._tick_energy(0.01)
	enemy.take_hit(1)
	check(player.energy == 1, "a real hit at a quarter second grants exactly one energy")
	for pellet in 30:
		enemy.take_hit(1, Vector2.ZERO, 0, false, {Elements.Type.WOOD: 0.35, Elements.Type.FIRE: 0.35})
	check(player.energy == 1, "pellets and multiple elemental numbers share the same recharge limit")
	player._tick_energy(10)
	check(player.energy == 1, "remaining in combat without dealing damage never grants energy")
	enemy.take_hit(1)
	check(player.energy == 2, "a hit after a long gap grants only one point without banking idle time")
	player._tick_energy(2)
	enemy.take_hit(0)
	check(player.energy == 2, "zero damage does not regenerate energy")
	get_tree().paused = true
	var remaining := player.energy_regen_remaining
	player._tick_energy(10)
	enemy.take_hit(1)
	check(player.energy == 2 and player.energy_regen_remaining == remaining, "pause freezes energy and rejects manually injected hits")
	get_tree().paused = false
	enemy.take_hit(1)
	check(player.energy == 3, "valid damage can resume regeneration after unpausing")
	arena.phase = Arena.Phase.EXPLORATION
	player._tick_energy(5)
	enemy.take_hit(1)
	check(player.energy == 3 and not player.energy_charge_started, "leaving combat preserves stored energy and resets the recharge timer")
	arena.phase = Arena.Phase.COMBAT
	enemy.take_hit(1)
	check(player.energy == 3 and player.energy_regen_remaining == Player.ENERGY_REGEN_INTERVAL, "a new fight cannot claim banked recharge progress")
	player._tick_energy(2)
	enemy.take_hit(1)
	check(player.energy == 4, "the new fight charges normally after its interval")
	var another := make_enemy()
	for index in 4:
		player._tick_energy(Player.ENERGY_REGEN_INTERVAL / 4.0)
		another.take_hit(1)
		enemy.take_hit(1)
	check(player.energy == 5, "damage to several enemies cannot multiply the recharge rate")
	another.queue_free()

func test_damage_types() -> void:
	var player := arena.player
	reset_energy()
	enemy.apply_burn(12)
	enemy._tick_status_effects(0.5)
	player._tick_energy(2)
	enemy._tick_status_effects(0.5)
	check(player.energy == 1, "actual burning damage follows the same recharge interval")
	enemy.burn_time = 0
	reset_energy()
	arena.active_room = 5
	arena.current_floor = 5
	arena._spawn_boss(arena.dungeon.room_center(5), Arena.BOSS_DATA[4])
	var warden := get_tree().get_first_node_in_group("bosses") as BastionWarden
	warden.set_physics_process(false)
	warden.take_hit(1)
	player._tick_energy(2)
	warden.take_hit(1)
	check(player.energy == 1, "actual damage to the final boss shield counts toward regeneration")
	warden.take_hit(99999)
	warden.take_hit(99999)
	check(warden.state == DungeonBoss.State.REFORGE, "test reaches the final boss immune transition")
	player._tick_energy(2)
	warden.take_hit(99999)
	check(player.energy == 1, "invulnerable reforge hits cannot grant energy")
	warden.queue_free()
	await frames()
	reset_energy()
	arena.current_floor = 4
	arena._spawn_boss(arena.dungeon.room_center(5), Arena.BOSS_DATA[3])
	var assassin := get_tree().get_first_node_in_group("bosses") as EmberStalker
	assassin.set_physics_process(false)
	assassin._start_slam()
	enemy.take_hit(1)
	player._tick_energy(2)
	assassin.take_hit(10)
	check(player.energy == 0, "blink immunity cannot be used to charge energy")
	assassin.queue_free()
	await frames()
	reset_energy()
	enemy.take_hit(1)
	player._tick_energy(2)
	var weapon := player.weapon_controller.current_weapon as WeaponMelee
	weapon.pivot.global_rotation = PI
	weapon.use_weapon()
	check(player.energy == 0, "a manually triggered melee swing that misses does not grant energy")
	weapon.can_use = true
	weapon.attack_time = 0
	weapon.pivot.global_rotation = 0
	weapon.use_weapon()
	check(player.energy == 1, "a manual melee hit reaches the real damage-to-energy path")
	reset_energy()
	enemy.take_hit(1)
	player._tick_energy(2)
	var bullet := preload("res://Scene/Bullets/bullet_pistol.tscn").instantiate() as Bullet
	bullet.setup(preload("res://Data/Weapons/weapon_pistol.tres"), 1, 0)
	add_child(bullet)
	bullet._on_body_entered(enemy)
	check(player.energy == 1, "a real bullet hit reaches the same damage-to-energy path")
	var dying := make_enemy()
	dying.health_component.current_health = 1
	player._tick_energy(2)
	dying.take_hit(10)
	check(player.energy == 2, "a lethal hit grants energy before the enemy is freed")
	player._tick_energy(2)
	dying.take_hit(10)
	check(player.energy == 2, "attacking an already dead enemy cannot grant energy")
	dying.queue_free()
	await frames()

func test_capacity_and_persistence() -> void:
	var player := arena.player
	reset_energy()
	enemy.take_hit(1)
	for index in 40:
		player._tick_energy(2)
		enemy.take_hit(1)
	check(player.energy == 30, "energy is capped at exactly thirty points")
	check(arena.hud.energy_bars.all(func(bar: ProgressBar) -> bool: return bar.value == 10), "thirty energy fills exactly three cells")
	player._tick_energy(20)
	check(player.consume_energy(10) and player.energy == 20, "skill interface can consume one complete cell")
	enemy.take_hit(1)
	check(player.energy == 20, "time spent at full capacity does not bank an instant refill")
	check(player.consume_energy(20) and player.energy == 0, "skill interface can consume two complete cells")
	check(not player.consume_energy(10) and not player.consume_energy(0) and not player.consume_energy(-1), "insufficient and invalid skill costs are rejected")
	player.energy = 17
	player.energy_changed.emit(17, Player.MAX_ENERGY)
	check(arena.hud.energy_bars[0].value == 10 and arena.hud.energy_bars[1].value == 7 and arena.hud.energy_bars[2].value == 0, "partial energy fills the second cell without filling the third")
	check(arena.hud.energy_bars.size() == 3 and arena.hud.energy_bars[0].position.y > arena.hud.health_bar.position.y + arena.hud.health_bar.size.y, "three energy cells are directly below the player health bar")
	arena.current_floor = 1
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	check(arena.choose_floor_reward(1), "test can select a real floor reward")
	await frames(5)
	check(arena.current_floor == 2 and arena.player == player and player.energy == 17, "changing floors keeps the player's stored energy")
	var fresh := preload("res://Scene/Play/player_bunny.tscn").instantiate() as Player
	fresh.data = preload("res://Data/Player/player_bunny.tres")
	add_child(fresh)
	fresh.set_physics_process(false)
	check(fresh.energy == 0, "a newly created player starts a fresh run with empty energy")
	fresh.queue_free()

func capture_hud() -> void:
	var folder := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	if folder.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(folder)
	arena.hud.toast_time = 0
	arena.hud.update_health(arena.player.health_component.current_health, arena.player.health_component.max_health)
	arena.player.get_node("Camera2D").reset_smoothing()
	for energy_value in [0, 9, 10, 17, 19, 20, 29, 30]:
		arena.player.energy = energy_value
		arena.player.energy_changed.emit(energy_value, Player.MAX_ENERGY)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder + "energy-%d.png" % energy_value)
	arena.player.consume_energy(20)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "energy-after-spend.png")

func run() -> void:
	Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	enemy = make_enemy()
	await frames()
	await test_rate()
	await test_damage_types()
	await test_capacity_and_persistence()
	await capture_hud()
	print("RESULT: %d/%d energy checks passed" % [checks - failures, checks])
	arena.queue_free()
	await frames()
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
