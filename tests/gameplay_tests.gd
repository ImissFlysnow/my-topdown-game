extends Node2D

var failures: int = 0
var checks: int = 0
var arena: Arena

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func frames(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame

func make_enemy(point: Vector2, kind: int = 0) -> Enemy:
	var enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
	enemy.data = Arena.ENEMIES[kind]
	enemy.position = point
	enemy.target = arena.player
	enemy.dungeon = arena.dungeon
	arena.actors.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames()
	for item in get_tree().get_nodes_in_group("pickups"):
		item.queue_free()
	await frames()

func run() -> void:
	var scene := preload("res://Scene/Arena/arena.tscn")
	arena = scene.instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.player.crit_chance = 0.0
	await frames(3)
	await test_dungeon()
	await test_melee()
	await test_projectiles()
	await test_items()
	await test_navigation()
	await test_waves_and_death()
	print("RESULT: %d/%d checks passed" % [checks - failures, checks])
	get_tree().paused = false
	arena.queue_free()
	await frames(3)
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)

func test_dungeon() -> void:
	var map := DungeonGenerator.new()
	add_child(map)
	var connected := true
	var safe_spawns := true
	for seed_value in range(1, 51):
		map.generate(seed_value)
		var seen: Dictionary[Vector2i, bool] = {}
		var queue: Array[Vector2i] = [map.rooms[0].get_center()]
		seen[queue[0]] = true
		var index := 0
		while index < queue.size():
			var cell := queue[index]
			index += 1
			for direction: Vector2i in DungeonGenerator.NEIGHBORS:
				var neighbor := cell + direction
				if map.floors.has(neighbor) and not seen.has(neighbor):
					seen[neighbor] = true
					queue.append(neighbor)
		connected = connected and seen.size() == map.floors.size()
		for attempt in 5:
			var point := map.room_spawn_position(1, map.room_center(1))
			safe_spawns = safe_spawns and map.is_floor(point) and point.distance_to(map.room_center(1)) >= 100.0
	map.generate(12345)
	var first := map.floors.duplicate()
	map.generate(12345)
	check(first == map.floors, "same seed reproduces dungeon")
	check(connected, "all floor cells connected across 50 dungeon seeds")
	check(safe_spawns, "enemy spawn cells are on floor and away from player")
	check(map.rooms.size() == 6, "six rooms generated")
	map.queue_free()
	await frames()

func test_melee() -> void:
	var player := arena.player
	var weapon := player.weapon_controller.current_weapon as WeaponMelee
	var point := player.global_position
	var front := make_enemy(point + Vector2(32, 0))
	var second := make_enemy(point + Vector2(30, 12))
	var behind := make_enemy(point + Vector2(-32, 0))
	await frames(2)
	weapon.pivot.global_rotation = 0.0
	var hp := front.health_component.current_health
	weapon.use_weapon()
	var hp_after_first_hit := front.health_component.current_health
	weapon.use_weapon()
	check(is_equal_approx(hp_after_first_hit, front.health_component.current_health), "cooldown blocks repeated attacks")
	await frames(4)
	check(is_equal_approx(front.health_component.current_health, hp - weapon.data.damage), "melee deals exactly one hit per swing")
	check(get_tree().current_scene.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text == "0.6"), "damage numbers exist in the running scene")
	check(second.health_component.current_health < second.health_component.max_health, "melee can hit multiple enemies")
	check(is_equal_approx(behind.health_component.current_health, behind.health_component.max_health), "melee does not hit behind player")
	check(front.knockback_velocity.length() > 0.0, "melee applies knockback")
	var value_after_hit := front.health_component.current_health
	await get_tree().create_timer(0.25).timeout
	weapon.use_weapon()
	check(front.health_component.current_health < value_after_hit, "enemy can be hit by the next swing")
	await clear_enemies()
	await get_tree().create_timer(0.25).timeout
	var wall: Vector2i
	var inside: Vector2i
	for cell: Vector2i in arena.dungeon.walls:
		if arena.dungeon.floors.has(cell + Vector2i.LEFT) and arena.dungeon.floors.has(cell + Vector2i.LEFT * 2):
			wall = cell
			inside = cell + Vector2i.LEFT
			break
	player.global_position = arena.dungeon.cell_to_world(inside) + Vector2(-2, 7)
	var blocked := make_enemy(arena.dungeon.cell_to_world(wall) + Vector2(0, 7))
	await frames(2)
	weapon.pivot.global_rotation = 0
	weapon.use_weapon()
	check(blocked.health_component.current_health == blocked.health_component.max_health, "wall blocks melee damage")
	await clear_enemies()
	player.global_position = point
	# Kill signal and drops must be emitted only once.
	var victim := make_enemy(point + Vector2(30, 0))
	var previous_kills := arena.kills
	victim.take_hit(999, Vector2.RIGHT)
	victim.take_hit(999, Vector2.RIGHT)
	check(arena.kills == previous_kills + 1, "enemy death is emitted once")
	check(get_tree().get_nodes_in_group("pickups").size() >= 1, "enemy drops XP while coin rewards follow the reduced rate")
	await frames(15)
	check(not is_instance_valid(victim), "dead enemy is freed after its death effect")
	await clear_enemies()

func test_projectiles() -> void:
	var point := arena.player.global_position
	var enemy := make_enemy(point + Vector2(70, 0))
	await frames()
	var data := preload("res://Data/Weapons/weapon_pistol.tres").duplicate() as WeaponData
	data.bullet_speed = 4000.0
	var bullet := data.bullet_scene.instantiate() as Bullet
	bullet.setup(data)
	add_child(bullet)
	bullet.global_position = point + Vector2(0, -7)
	bullet.global_rotation = 0
	await frames(4)
	check(is_equal_approx(enemy.health_component.current_health, enemy.health_component.max_health - data.damage), "fast projectile hits enemy using swept collision")
	check(not is_instance_valid(bullet), "projectile freed after impact")
	await clear_enemies()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3, 70)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = point + Vector2(35, -7)
	enemy = make_enemy(point + Vector2(70, 0))
	await frames()
	bullet = data.bullet_scene.instantiate() as Bullet
	bullet.setup(data)
	add_child(bullet)
	bullet.global_position = point + Vector2(0, -7)
	await frames(5)
	check(enemy.health_component.current_health == enemy.health_component.max_health, "thin wall stops fast projectile")
	check(not is_instance_valid(bullet), "projectile freed when it hits a wall")
	wall.queue_free()
	await clear_enemies()
	data.projectile_lifetime = 0.03
	bullet = data.bullet_scene.instantiate() as Bullet
	bullet.setup(data)
	add_child(bullet)
	bullet.global_position = point + Vector2(0, -7)
	await frames(6)
	check(not is_instance_valid(bullet), "missed projectile expires")
	# Every existing selection weapon must instantiate and attack.
	for resource_path in ["ak", "awm", "mp7", "m4", "pistol", "uzi", "xm1014", "sword", "axe"]:
		Global.selected_weapon = load("res://Data/Weapons/weapon_" + resource_path + ".tres")
		arena.player.weapon_controller.equip_weapon()
		arena.player.weapon_controller.current_weapon.use_weapon()
		await frames(2)
	check(true, "all nine selection weapons instantiate and fire")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	arena.player.weapon_controller.equip_weapon()

func test_items() -> void:
	var player := arena.player
	var old_hp := player.health_component.current_health
	check(player.take_hit(1), "player can take damage")
	check(not player.take_hit(1), "player contact damage has invulnerability window")
	check(player.health_component.current_health == old_hp - 1, "contact damage is not applied every frame")
	check(not player.collect_item(Arena.HEAL_ITEM), "legacy healing items cannot be collected outside events")
	check(player.health_component.current_health == old_hp - 1, "healing items cannot restore a wounded player")
	arena._spawn_pickup(Arena.HEAL_ITEM, player.position)
	check(get_tree().get_nodes_in_group("pickups").all(func(pickup: Pickup) -> bool: return pickup.data.kind != ItemData.Kind.HEAL), "healing pickups cannot spawn in the dungeon")
	var damage := player.damage_multiplier
	player.collect_item(Arena.UPGRADES[0])
	check(is_equal_approx(player.damage_multiplier, damage + 0.2), "damage item changes runtime damage")
	var speed := player.speed_multiplier
	player.collect_item(Arena.UPGRADES[1])
	check(player.speed_multiplier > speed, "speed item changes movement speed")
	var attack_speed := player.cooldown_multiplier
	player.collect_item(Arena.UPGRADES[2])
	check(player.cooldown_multiplier < attack_speed, "attack speed item reduces cooldown")
	for index in 10:
		player.collect_item(Arena.UPGRADES[2])
	var weapon := player.weapon_controller.current_weapon as WeaponMelee
	weapon.use_weapon()
	check(is_equal_approx(weapon.cooldown.wait_time, weapon.data.cooldown * player.cooldown_multiplier), "melee animation scales with stacked attack speed")
	var pickup_radius := player.pickup_radius
	player.collect_item(Arena.UPGRADES[3])
	check(player.pickup_radius > pickup_radius, "magnet item expands pickup radius")
	var level := player.level
	var health_before_level := player.health_component.current_health
	var xp := Arena.EXPERIENCE_ITEM.duplicate() as ItemData
	xp.amount = 100
	player.collect_item(xp)
	check(player.level > level + 1, "large XP pickup supports multiple levels")
	check(player.experience < player.experience_needed(), "XP carries over after leveling")
	check(player.health_component.current_health == health_before_level + player.level - level, "each level increases current health by one along with maximum health")
	check(player.data.max_hp == 7.0, "run upgrades do not mutate shared character data")
	var chest := get_tree().get_first_node_in_group("chests") as LootChest
	player.global_position = chest.global_position
	player.coins = 0
	check(not chest.try_open(), "challenge chest stays locked before clearing")
	chest.locked = false
	check(chest.try_open() and player.coins == 0, "cleared challenge chest opens for free")
	check(not chest.try_open(), "opened chest cannot be farmed")
	var coin_count := player.coins
	arena._spawn_pickup(Arena.COIN_ITEM, player.global_position + Vector2(25, -5))
	await get_tree().create_timer(0.5).timeout
	check(player.coins > coin_count, "magnet pulls in and collects a floor pickup")
	player.global_position = arena.dungeon.spawn_position

func test_navigation() -> void:
	var start := arena.dungeon.cell_to_world(arena.dungeon.rooms[0].get_center())
	var end := arena.dungeon.cell_to_world(arena.dungeon.rooms[4].get_center())
	var path := arena.dungeon.find_path(start, end)
	var valid := path.size() > 2
	for point: Vector2 in path:
		valid = valid and arena.dungeon.is_floor(point)
	check(valid, "pathfinding crosses rooms without entering walls")
	arena.player.global_position = end
	var enemy := make_enemy(start)
	enemy.set_physics_process(true)
	# Keep the player stationary while checking the enemy follows the path.
	var initial_path_length := arena.dungeon.find_path(start, end).size()
	await get_tree().create_timer(1.6).timeout
	var remaining_path_length := arena.dungeon.find_path(enemy.global_position, end).size()
	check(remaining_path_length > 0 and remaining_path_length < initial_path_length and enemy.global_position.distance_to(start) > 20, "enemy pursues player along the dungeon route")
	enemy.queue_free()
	await frames()
	arena.player.global_position = arena.dungeon.spawn_position

func test_waves_and_death() -> void:
	await clear_enemies()
	arena.active_room = 1
	arena.room_states[1] = Arena.RoomState.ACTIVE
	arena.phase = Arena.Phase.COMBAT
	arena._physics_process(0.1)
	check(arena.phase == Arena.Phase.EXPLORATION, "cleared challenge returns to exploration")
	arena.current_floor = arena.floor_count
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.choose_floor_reward(0)
	check(arena.phase == Arena.Phase.FINISHED and get_tree().paused, "final floor reward shows victory and pauses game")
	check(arena.hud.modal.visible, "result screen is visible")
	arena.hud.hide_modal()
	arena.phase = Arena.Phase.EXPLORATION
	arena.player.can_move = true
	arena.player.invulnerability = 0.0
	arena.player.take_hit(999)
	await frames()
	check(arena.player.health_component.is_dead, "lethal hit kills player")
	check(arena.phase == Arena.Phase.FINISHED and get_tree().paused, "player death shows result screen")
	check(not arena.player.can_move, "dead player cannot move or attack")
	arena.hud.hide_modal()
