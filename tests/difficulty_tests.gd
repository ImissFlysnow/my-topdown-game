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

func flood(map: DungeonGenerator) -> int:
	var queue: Array[Vector2i] = [map.rooms[0].get_center()]
	var seen: Dictionary[Vector2i, bool] = {queue[0]: true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in DungeonGenerator.NEIGHBORS:
			var neighbor := cell + direction
			if map.floors.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen.size()

func test_maps() -> void:
	var map := DungeonGenerator.new()
	add_child(map)
	var layouts: Dictionary = {}
	var topologies: Dictionary = {}
	var shop_quadrants: Dictionary = {}
	var boss_quadrants: Dictionary = {}
	for width in [3, 5, 7]:
		map.corridor_width = width
		var connected := true
		var bounds_ok := true
		var rooms_separate := true
		var gates_ok := true
		var accessible := true
		var spawns_ok := true
		var composition := true
		var boss_leaf := true
		var direct_halls := true
		for seed_value in range(1, 101):
			map.generate(seed_value)
			var bounds := Rect2i(Vector2i.ZERO, map.grid_size)
			composition = composition and map.rooms.size() == 6 and map.room_types.count(DungeonGenerator.RoomType.CHALLENGE) == 3 and map.room_types.count(DungeonGenerator.RoomType.SHOP) == 1 and map.room_types.count(DungeonGenerator.RoomType.EVENT) == 1 and map.room_types.count(DungeonGenerator.RoomType.BOSS) == 1
			connected = connected and flood(map) == map.floors.size()
			for cell: Vector2i in map.floors:
				bounds_ok = bounds_ok and bounds.has_point(cell)
			for cell: Vector2i in map.walls:
				bounds_ok = bounds_ok and bounds.has_point(cell)
			for first in 6:
				bounds_ok = bounds_ok and bounds.encloses(map.rooms[first])
				for second in range(first + 1, 6):
					rooms_separate = rooms_separate and not map.rooms[first].grow(width + 2).intersects(map.rooms[second])
				var point := map.room_spawn_position(first, map.room_center(first))
				spawns_ok = spawns_ok and map.room_world_rect(first, 48).has_point(point) and map.is_floor(point)
			map.seal_room(5, true)
			gates_ok = gates_ok and map.find_path(map.room_center(0), map.room_center(5)).is_empty() and not map.gate_bodies[5].get_children().is_empty()
			for room in [1, 2, 3, 4]:
				accessible = accessible and not map.find_path(map.room_center(0), map.room_center(room)).is_empty()
			map.seal_room(5, false)
			gates_ok = gates_ok and not map.find_path(map.room_center(0), map.room_center(5)).is_empty()
			boss_leaf = boss_leaf and map.connections.filter(func(pair: Vector2i) -> bool: return pair.x == 5 or pair.y == 5).size() == 1
			direct_halls = direct_halls and map.connections.size() == 5
			for pair: Vector2i in map.connections:
				var first_center := map.rooms[pair.x].get_center()
				var second_center := map.rooms[pair.y].get_center()
				var offset := (first_center - second_center).abs()
				direct_halls = direct_halls and (offset.x == 0 or offset.y == 0) and offset.x + offset.y <= maxi(map.grid_size.x / 2, map.grid_size.y / 2) + 2
			if width == 5:
				layouts[str(map.rooms)] = true
				var pairs := PackedStringArray()
				for pair: Vector2i in map.connections:
					pairs.append("%d-%d" % [pair.x, pair.y])
				pairs.sort()
				topologies[",".join(pairs)] = true
				var shop := map.rooms[0].get_center()
				var boss := map.rooms[5].get_center()
				shop_quadrants[Vector2i(int(shop.x >= map.grid_size.x / 2), int(shop.y >= map.grid_size.y / 2))] = true
				boss_quadrants[Vector2i(int(boss.x >= map.grid_size.x / 2), int(boss.y >= map.grid_size.y / 2))] = true
			if seed_value % 10 == 0:
				await get_tree().process_frame
		check(composition, "100 seeds / width %d retain six designated rooms" % width)
		check(connected, "100 seeds / width %d have connected walkable tiles" % width)
		check(bounds_ok, "100 seeds / width %d keep floors, walls and rooms inside bounds" % width)
		check(rooms_separate, "100 seeds / width %d leave safe corridor spacing between rooms" % width)
		check(gates_ok, "100 seeds / width %d boss doors physically seal and reopen" % width)
		check(accessible, "100 seeds / width %d keep all non-boss rooms reachable while boss is locked" % width)
		check(spawns_ok, "100 seeds / width %d have safe room spawn positions" % width)
		check(boss_leaf, "100 seeds / width %d never use the boss as a route between rooms" % width)
		check(direct_halls, "100 seeds / width %d use exactly five short straight halls" % width)
	check(layouts.size() == 100, "100 seeds produce 100 distinct spatial room layouts")
	check(topologies.size() > 30, "room connections vary substantially across seeds")
	check(shop_quadrants.size() == 4 and boss_quadrants.size() == 4, "shop and boss can appear in every map quadrant")
	map.corridor_width = 5
	map.generate(2026)
	var first_rooms := map.rooms.duplicate()
	var first_floors := map.floors.duplicate()
	var first_connections := map.connections.duplicate()
	map.generate(2026)
	check(map.rooms == first_rooms and map.floors == first_floors and map.connections == first_connections, "seed reproduces both room geometry and corridor connections")
	var floor_layouts: Dictionary = {}
	for floor_number in 5:
		map.generate(2026 + floor_number * 104729)
		floor_layouts[str(map.rooms)] = true
	check(floor_layouts.size() == 5, "a five-floor run produces five different layouts")
	map.queue_free()
	await frames()

func coin_pickup_total() -> int:
	var total := 0
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.data.kind == ItemData.Kind.COIN:
			total += int(pickup.data.amount)
	return total

func test_coin_rewards() -> void:
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 4156
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	var point := arena.dungeon.room_center(1)
	arena._on_enemy_killed(point, 0, 1)
	check(coin_pickup_total() == 0 and is_equal_approx(arena.coin_drop_remainder, 0.65), "first one-coin kill carries 0.65 fractional reward")
	arena._on_enemy_killed(point, 0, 1)
	check(coin_pickup_total() == 1 and is_equal_approx(arena.coin_drop_remainder, 0.3), "two one-coin enemies drop one coin and carry 0.3")
	arena._on_enemy_killed(point, 0, 3)
	arena._on_enemy_killed(point, 0, 12)
	check(coin_pickup_total() == 11 and is_equal_approx(arena.coin_drop_remainder, 0.05), "mixed rewards total 65 percent: 30 percent above the previous 50 percent")
	arena._on_enemy_killed(point, 0, 0)
	check(coin_pickup_total() == 11 and is_equal_approx(arena.coin_drop_remainder, 0.05), "zero-value summons neither grant coins nor change remainder")
	arena._on_enemy_killed(point, 0, 1)
	check(coin_pickup_total() == 11 and is_equal_approx(arena.coin_drop_remainder, 0.7), "later odd reward retains its fraction without losing income")
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	await frames()
	arena.coin_drop_remainder = 0
	for index in 100:
		arena._on_enemy_killed(point, 0, 1)
	check(coin_pickup_total() == 65 and is_zero_approx(arena.coin_drop_remainder), "100 one-coin enemies yield exactly 65 coins")
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		arena.player.collect_item(pickup.data)
		pickup.queue_free()
	check(arena.player.coins == 65, "collected coin total matches 30 percent increased drops")
	await frames()
	arena._on_enemy_killed(point, 0, 1)
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.choose_floor_reward(1)
	await frames(5)
	arena._on_enemy_killed(arena.dungeon.room_center(1), 0, 1)
	check(arena.current_floor == 2 and coin_pickup_total() == 1 and is_equal_approx(arena.coin_drop_remainder, 0.3), "changing floors retains fractional coin credit")
	arena.queue_free()
	await frames()

func test_healing() -> void:
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 4156
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	await frames()
	check(get_tree().get_nodes_in_group("pickups").is_empty(), "floor start has no free healing pickup")
	check(arena.shop_offers.size() == 3 and arena.shop_offers.all(func(offer: Dictionary) -> bool: return offer.item.kind >= ItemData.Kind.DAMAGE), "shop offers three permanent upgrades without healing")
	var stocks: Dictionary = {}
	for offer: Dictionary in arena.shop_offers:
		stocks[offer.item] = true
	check(stocks.size() == 3, "shop offers three different upgrades")
	arena.player.health_component.current_health = 3
	check(not arena.player.collect_item(Arena.HEAL_ITEM) and arena.player.health_component.current_health == 3, "legacy health items cannot restore life outside events")
	arena._spawn_pickup(Arena.HEAL_ITEM, arena.player.position)
	check(get_tree().get_nodes_in_group("pickups").is_empty(), "legacy healing drops cannot be spawned")
	for index in 100:
		arena._on_enemy_killed(arena.dungeon.room_center(1), 1, 1)
	check(get_tree().get_nodes_in_group("pickups").all(func(pickup: Pickup) -> bool: return pickup.data.kind != ItemData.Kind.HEAL), "100 enemy kills produce no health potions")
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	await frames()
	var xp := Arena.EXPERIENCE_ITEM.duplicate() as ItemData
	xp.amount = 100
	var level_before := arena.player.level
	arena.player.collect_item(xp)
	var health_after_levels := 3.0 + arena.player.level - level_before
	check(arena.player.health_component.current_health == health_after_levels and arena.player.health_component.max_health > arena.player.data.max_hp, "multiple level-ups add one current and maximum health per level")
	arena.active_room = 1
	arena.room_states[1] = Arena.RoomState.ACTIVE
	arena.phase = Arena.Phase.COMBAT
	arena._complete_active_room()
	check(arena.player.health_component.current_health == health_after_levels and not arena.room_chests[1].locked, "challenge clear unlocks chest without healing")
	arena.player.position = arena.shop_service.position
	arena.player.coins = 100
	var price: int = arena.shop_offers[0].price
	check(arena.buy_shop(0) and arena.player.health_component.current_health == health_after_levels and arena.player.coins == 100 - price, "buying a permanent upgrade never heals")
	arena.hud.hide_modal()
	for kind in 3:
		arena.event_kind = kind
		arena.event_resolved = false
		arena.event_service.resolved = false
		arena.player.position = arena.event_service.position
		var option := 0 if kind == 2 else 1
		arena.player.health_component.current_health = arena.player.health_component.max_health
		check(not arena.resolve_event(option) and not arena.event_resolved, "event %d refuses unnecessary healing without consuming its choice" % kind)
		arena.player.health_component.current_health -= 4
		var hp := arena.player.health_component.current_health
		check(arena.resolve_event(option) and is_equal_approx(arena.player.health_component.current_health, hp + [2, 1, 3][kind]), "event %d restores its advertised health amount" % kind)
		check(not arena.resolve_event(option), "event %d healing cannot be repeated" % kind)
	arena.event_resolved = false
	arena.event_service.resolved = false
	arena.event_kind = 2
	arena.player.health_component.current_health = 3
	arena.player.position = arena.shop_service.position
	check(not arena.resolve_event(0) and arena.player.health_component.current_health == 3, "event healing requires physically visiting the event room")
	arena.player.position = arena.event_service.position
	arena.phase = Arena.Phase.COMBAT
	check(not arena.resolve_event(0) and arena.player.health_component.current_health == 3, "event healing cannot be activated during sealed combat")
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	var capacity := arena.player.health_component.max_health
	var old_rooms := arena.dungeon.rooms.duplicate()
	check(arena.choose_floor_reward(0) and arena.player.health_component.max_health == capacity + 3 and arena.player.health_component.current_health == 3, "floor attribute reward increases capacity without healing")
	await frames(5)
	check(arena.current_floor == 2 and arena.player.health_component.current_health == 3, "changing floors preserves wounds")
	check(arena.dungeon.rooms != old_rooms and arena.room_chests.size() == 3, "next floor changes spatial layout and preserves three challenge chests")
	check(get_tree().get_nodes_in_group("pickups").is_empty(), "next floor generates no healing pickups")
	arena.queue_free()
	await frames()

func run() -> void:
	await test_maps()
	await test_coin_rewards()
	await test_healing()
	print("RESULT: %d/%d difficulty checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
