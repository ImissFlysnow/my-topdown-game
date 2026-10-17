extends Node2D

var checks := 0
var failures := 0
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

func frames(count: int = 3) -> void:
	for index in count:
		await get_tree().process_frame
		await get_tree().physics_frame

func run() -> void:
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 8080
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	await frames()
	await test_map()
	await test_elements()
	await test_rooms_and_boss()
	await test_rewards_and_services()
	await test_remaining_floors()
	print("RESULT: %d/%d roguelike checks passed" % [checks - failures, checks])
	get_tree().paused = false
	arena.queue_free()
	await frames()
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)

func test_map() -> void:
	var map := DungeonGenerator.new()
	add_child(map)
	var connected := true
	var composition := true
	var spawns_safe := true
	for seed_value in range(1, 51):
		map.generate(seed_value)
		composition = composition and map.rooms.size() == 6
		composition = composition and map.room_types.count(DungeonGenerator.RoomType.CHALLENGE) == 3
		composition = composition and map.room_types.count(DungeonGenerator.RoomType.SHOP) == 1
		composition = composition and map.room_types.count(DungeonGenerator.RoomType.EVENT) == 1
		composition = composition and map.room_types.count(DungeonGenerator.RoomType.BOSS) == 1
		var queue: Array[Vector2i] = [map.rooms[0].get_center()]
		var seen: Dictionary[Vector2i, bool] = {queue[0]: true}
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			for direction: Vector2i in DungeonGenerator.NEIGHBORS:
				var next := cell + direction
				if map.floors.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		connected = connected and seen.size() == map.floors.size()
		for index in [1, 3, 4]:
			var point := map.room_spawn_position(index, map.room_center(index))
			spawns_safe = spawns_safe and map.room_world_rect(index, 48).has_point(point)
	check(composition, "50 seeds each have exactly 3 challenge + 1 shop + 1 event + 1 boss room")
	check(connected, "all six-room dungeon floors are connected")
	check(spawns_safe, "challenge wave spawn positions stay within their room")
	map.generate(99)
	var first := map.floors.duplicate()
	map.generate(99)
	check(first == map.floors, "floor generation remains deterministic")
	map.seal_room(5, true)
	check(map.find_path(map.room_center(0), map.room_center(5)).is_empty(), "locked boss room cannot be reached through navigation")
	check(not map.gate_bodies[5].get_children().is_empty(), "sealed room has physical door colliders")
	map.seal_room(5, false)
	check(not map.find_path(map.room_center(0), map.room_center(5)).is_empty(), "opening boss doors restores its path")
	map.queue_free()
	await frames()

func test_elements() -> void:
	var exact := true
	for attack in range(1, 6):
		for defense in range(1, 6):
			var expected := 1.0
			if Elements.COUNTERS[attack] == defense:
				expected = 1.5
			elif Elements.COUNTERS[defense] == attack:
				expected = 0.65
			exact = exact and is_equal_approx(Elements.multiplier(attack, defense), expected)
	check(exact, "all 25 five-element matchups have correct counter and weakness factors")
	check(Elements.multiplier(0, 4) == 1 and Elements.multiplier(1, 0) == 1, "physical and neutral damage have no elemental penalty")
	check(Elements.color(1) != Elements.color(2) and Elements.color(3) != Elements.color(4), "elemental damage uses distinct colors")
	var enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
	enemy.data = Arena.ENEMIES[0]
	enemy.element = Elements.Type.WOOD
	enemy.health_scale = 100
	enemy.position = arena.player.position + Vector2(90, 0)
	arena.actors.add_child(enemy)
	enemy.set_physics_process(false)
	var hp := enemy.health_component.current_health
	enemy.take_hit(10, Vector2.ZERO, 0, false, {Elements.Type.METAL: 0.35})
	check(is_equal_approx(enemy.health_component.current_health, hp - 15.25), "metal enchant adds 1.5x elemental damage against wood")
	var labels := find_children("*", "Label", true, false)
	check(labels.any(func(label: Label) -> bool: return label.text.ends_with("克") and label.get_theme_color("font_color") == Elements.color(Elements.Type.METAL)), "counter damage number keeps element color and counter label")
	enemy.health_component.init_health(300)
	enemy.element = Elements.Type.FIRE
	enemy.take_hit(10, Vector2.ZERO, 0, true, {Elements.Type.METAL: 0.35})
	check(is_equal_approx(enemy.health_component.current_health, 300 - 12.275), "metal elemental damage is weakened against fire while physical damage stays intact")
	labels = find_children("*", "Label", true, false)
	check(labels.any(func(label: Label) -> bool: return label.text.ends_with("弱") and label.get_theme_color("font_color") == Elements.color(Elements.Type.METAL)), "critical elemental damage retains element color")
	enemy.health_component.init_health(300)
	enemy.element = Elements.Type.NONE
	enemy.take_hit(10, Vector2.ZERO, 0, false, {Elements.Type.METAL: 0.35, Elements.Type.WATER: 0.35})
	check(is_equal_approx(enemy.health_component.current_health, 283), "multiple enchantments add once each without repeating physical damage")
	var affixes := {Elements.Type.FIRE: 0.35}
	var data := preload("res://Data/Weapons/weapon_pistol.tres")
	var bullet := data.bullet_scene.instantiate() as Bullet
	bullet.setup(data, 1, 0, affixes)
	affixes[Elements.Type.FIRE] = 0.7
	check(is_equal_approx(bullet.elements[Elements.Type.FIRE], 0.35), "projectile snapshots enchantments when fired")
	bullet.free()
	enemy.queue_free()
	await frames()

func clear_challenge(index: int) -> void:
	arena.player.global_position = arena.dungeon.room_center(index)
	arena._begin_combat_room(index)
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	await frames(5)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.take_hit(9999)
	await frames()
	arena._physics_process(0.01)

func make_boss() -> DungeonBoss:
	arena.player.global_position = arena.dungeon.room_center(5) + Vector2(-100, 0)
	arena._begin_combat_room(5)
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	await frames(5)
	return get_tree().get_first_node_in_group("bosses") as DungeonBoss

func complete_boss(boss: DungeonBoss) -> void:
	for attempt in 8:
		if boss.health_component.is_dead:
			break
		if boss.state == DungeonBoss.State.REFORGE:
			boss._tick_special_state(0.91)
		boss.take_hit(9999)
	await frames()
	arena._physics_process(0.01)
	await get_tree().create_timer(0.85).timeout
	arena._physics_process(1.0)

func test_rooms_and_boss() -> void:
	check(arena.dungeon.sealed_rooms.has(5), "boss is locked before three challenges are cleared")
	check(arena.room_chests.size() == 3, "each challenge room has exactly one chest")
	var chest: LootChest = arena.room_chests[1]
	arena.player.global_position = chest.global_position
	check(chest.locked and not chest.try_open(), "uncleared room chest cannot be opened")
	arena.player.global_position = arena.dungeon.room_center(1)
	arena._begin_combat_room(1)
	var count := get_tree().get_nodes_in_group("spawn_markers").size()
	check(count == 6, "first-floor first challenge schedules one six-enemy wave")
	arena._begin_combat_room(1)
	check(count == get_tree().get_nodes_in_group("spawn_markers").size(), "reentering an active room cannot schedule a second wave")
	check(arena.dungeon.sealed_rooms.has(1), "challenge room seals its doors during combat")
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	await frames(5)
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 6, "scheduled wave produces exactly six enemies")
	check(enemies.all(func(enemy: Enemy) -> bool: return enemy.element >= 1 and enemy.element <= 5), "challenge enemies receive five-element affinities")
	for enemy: Enemy in enemies:
		enemy.set_physics_process(false)
		enemy.take_hit(9999)
	await frames()
	arena._physics_process(0.01)
	check(arena.room_states[1] == Arena.RoomState.CLEARED and arena.cleared_challenges == 1, "killing the wave marks its room cleared")
	check(not arena.dungeon.sealed_rooms.has(1) and not chest.locked, "clearing unlocks room doors and chest")
	var initial_kills := arena.kills
	arena._begin_combat_room(1)
	check(arena.phase == Arena.Phase.EXPLORATION and arena.kills == initial_kills and get_tree().get_nodes_in_group("spawn_markers").is_empty(), "cleared rooms do not respawn waves")
	arena.player.global_position = chest.global_position + Vector2(0, 12)
	var coins := arena.player.coins
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	arena._unhandled_input(event)
	check(chest.opened and arena.player.coins == coins, "E opens cleared challenge chest for free")
	check(not chest.try_open(), "opened chest cannot be opened again")
	await get_tree().create_timer(0.2).timeout
	check(not arena.player.inventory.is_empty(), "challenge chest provides a permanent item")
	await clear_challenge(3)
	check(arena.dungeon.sealed_rooms.has(5), "two challenges do not unlock boss")
	await clear_challenge(4)
	check(arena.cleared_challenges == 3 and not arena.dungeon.sealed_rooms.has(5), "all three challenges unlock boss")
	var boss: DungeonBoss = await make_boss()
	check(is_instance_valid(boss), "boss room spawns an actual boss")
	boss.set_physics_process(false)
	check(boss.health_component.max_health > Arena.ENEMIES[2].max_health and boss.data.contact_damage > Arena.ENEMIES[0].contact_damage, "boss has higher health and damage than regular enemies")
	check(boss.get_node("CollisionShape2D").shape.radius > 20, "boss is physically larger than regular enemies")
	var animation_complete := true
	for name in ["idle", "walk", "attack", "death"]:
		animation_complete = animation_complete and boss.boss_sprite.sprite_frames.get_frame_count(name) == 4
	check(animation_complete, "generated boss sheet supplies four four-frame animation states")
	arena.player.health_component.heal(999)
	arena.player.invulnerability = 0
	var hp := arena.player.health_component.current_health
	boss._start_slam()
	check(get_tree().get_nodes_in_group("enemy_attacks").size() == 1, "boss attack creates a visible warning zone")
	await get_tree().create_timer(0.3).timeout
	check(arena.player.health_component.current_health == hp, "boss slam does not damage before its warning ends")
	await get_tree().create_timer(0.65).timeout
	check(arena.player.health_component.current_health < hp, "boss slam deals damage after warning")
	boss.health_component.current_health = boss.health_component.max_health * 0.4
	boss.state = DungeonBoss.State.CHASE
	boss.skill_time = 100
	boss._physics_process(0.01)
	check(boss.enraged, "boss becomes enraged below half health")
	boss._radial_burst()
	check(get_tree().get_nodes_in_group("enemy_attacks").filter(func(node: Node) -> bool: return node is EnemyProjectile).size() == 8, "enraged boss emits eight elemental projectiles")
	await complete_boss(boss)
	check(arena.phase == Arena.Phase.REWARD and get_tree().paused, "boss defeat opens paused three-choice floor reward")
	check(is_instance_valid(arena.exit_service), "cleared floor has a returnable exit portal")
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "boss defeat removes remaining dangerous attacks")

func test_rewards_and_services() -> void:
	check(not arena.choose_floor_reward(2, 0), "element reward rejects invalid neutral enchant")
	arena.defer_floor_reward()
	check(arena.phase == Arena.Phase.FLOOR_CLEARED and not get_tree().paused, "reward can be deferred to explore remaining rooms")
	arena.open_floor_rewards()
	arena.hud.show_elements()
	check(arena.hud.dialog_mode == "elements", "enchant reward opens element selection")
	var player_id := arena.player.get_instance_id()
	var seed := arena.dungeon.actual_seed
	check(arena.choose_floor_reward(2, Elements.Type.METAL), "first floor can grant a metal enchantment")
	check(not arena.choose_floor_reward(0), "same floor cannot grant a second reward")
	await frames(5)
	check(arena.current_floor == 2 and arena.player.get_instance_id() == player_id, "next floor preserves the actual player instance")
	check(is_equal_approx(arena.player.weapon_elements[Elements.Type.METAL], 0.35), "weapon enchant is retained across floors")
	check(arena.dungeon.actual_seed != seed and arena.room_chests.size() == 3, "next floor regenerates six rooms and three reward chests")
	check(arena.cleared_challenges == 0 and arena.dungeon.sealed_rooms.has(5), "next floor resets room progression and boss lock")
	check(arena.enemy_health_multiplier() > 1 and arena.enemy_damage_multiplier() > 1, "floor two has stronger enemies")
	arena.player.global_position = arena.shop_service.global_position
	arena.player.coins = 100
	arena.player.health_component.heal(999)
	var coins := arena.player.coins
	check(arena.shop_offers.all(func(offer: Dictionary) -> bool: return offer.item.kind >= ItemData.Kind.DAMAGE), "shop stocks only permanent upgrades")
	arena.player.health_component.take_damage(1)
	var health_before_purchase := arena.player.health_component.current_health
	var price: int = arena.shop_offers[0].price
	check(arena.buy_shop(0) and arena.player.coins == coins - price and arena.player.health_component.current_health == health_before_purchase, "shop purchase deducts exact price without healing")
	check(not arena.buy_shop(0), "shop item is limited to one purchase per floor")
	arena.hud.hide_modal()
	arena.player.coins = 0
	check(not arena.buy_shop(1), "shop blocks purchases without enough coins")
	arena.player.global_position = arena.event_service.global_position
	arena.event_kind = 0
	arena.player.health_component.current_health = 2
	check(not arena.resolve_event(0) and not arena.event_resolved, "sacrifice event cannot kill player")
	arena.player.health_component.heal(999)
	var damage := arena.player.damage_multiplier
	check(arena.resolve_event(0) and arena.player.damage_multiplier > damage, "sacrifice event trades life for permanent damage")
	check(not arena.resolve_event(1), "event reward cannot be claimed twice")
	arena.event_resolved = false
	arena.event_service.resolved = false
	arena.event_kind = 1
	arena.player.coins = 0
	check(not arena.resolve_event(0) and not arena.event_resolved, "traveler event rejects an unaffordable purchase")
	arena.player.coins = 8
	check(arena.resolve_event(0) and arena.player.coins == 0, "traveler event grants an item for exact payment")
	arena.event_resolved = false
	arena.event_service.resolved = false
	arena.event_kind = 2
	var cooldown := arena.player.cooldown_multiplier
	check(arena.resolve_event(1) and arena.player.cooldown_multiplier < cooldown, "spring event can grant attack speed")

func test_remaining_floors() -> void:
	var last_health := 45.0
	var last_damage := 2.0
	for floor_number in range(2, 6):
		for room in [1, 3, 4]:
			await clear_challenge(room)
		var boss: DungeonBoss = await make_boss()
		boss.set_physics_process(false)
		var health := boss.health_component.max_health
		var damage := boss.data.contact_damage * boss.damage_scale
		check(health > last_health and damage > last_damage, "floor %d boss health and damage increase" % floor_number)
		check(boss.element == floor_number, "floor %d boss uses its designated element" % floor_number)
		last_health = health
		last_damage = damage
		await complete_boss(boss)
		if floor_number == 2:
			var before_hp := arena.player.health_component.max_health
			var before_damage := arena.player.damage_multiplier
			arena.choose_floor_reward(0)
			check(arena.player.health_component.max_health >= before_hp + 3 and arena.player.damage_multiplier >= before_damage + 0.15, "attribute reward improves health and damage")
		elif floor_number == 3:
			var before_speed := arena.player.cooldown_multiplier
			arena.choose_floor_reward(1)
			check(arena.player.cooldown_multiplier < before_speed, "floor reward improves attack speed")
		elif floor_number == 4:
			arena.choose_floor_reward(2, Elements.Type.METAL)
			check(is_equal_approx(arena.player.weapon_elements[Elements.Type.METAL], 0.7), "choosing the same enchant twice stacks its bonus")
		else:
			arena.choose_floor_reward(2, Elements.Type.WATER)
		await frames(5)
	check(arena.current_floor == 5 and arena.phase == Arena.Phase.FINISHED and get_tree().paused, "fifth boss and fifth reward finish the run without generating floor six")
	check(arena.hud.modal_title.text == "五层地牢通关！", "full five-floor run reaches victory screen")
	check(arena.player.weapon_elements.size() == 2, "different elemental enchantments coexist")
