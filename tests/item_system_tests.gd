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

func setup_arena(ranged: bool = false) -> void:
	Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_pistol.tres") if ranged else preload("res://Data/Weapons/weapon_sword.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.player.invulnerability = 999
	await frames()

func cleanup() -> void:
	get_tree().paused = false
	for bullet in get_tree().get_nodes_in_group("player_projectiles"):
		bullet.queue_free()
	arena.queue_free()
	await frames()

func enemy_at(point: Vector2, elite: bool = false) -> Enemy:
	var enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
	enemy.data = Arena.ENEMIES[0].duplicate() as EnemyData
	enemy.data.max_health = 100
	enemy.data.elite = elite
	enemy.data.experience = 0
	enemy.data.coins = 0
	enemy.target = arena.player
	enemy.dungeon = arena.dungeon
	enemy.position = point
	arena.actors.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func make_boss(floor_number: int) -> DungeonBoss:
	arena.current_floor = floor_number
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 5
	arena._spawn_boss(arena.dungeon.room_center(5), Arena.BOSS_DATA[floor_number - 1])
	var boss := get_tree().get_first_node_in_group("bosses") as DungeonBoss
	boss.set_physics_process(false)
	return boss

func coin_total() -> int:
	var total := 0
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		if pickup.data.kind == ItemData.Kind.COIN:
			total += int(pickup.data.amount)
	return total

func test_tiers() -> void:
	var counts := [0, 0, 0, 0]
	for roll in 100:
		counts[ItemLoot.tier_for_roll(roll)] += 1
	check(counts == [50, 31, 16, 3], "all 100 tier rolls have exact 50/31/16/3 weights")
	check(ItemLoot.tier_for_roll(49) == 0 and ItemLoot.tier_for_roll(50) == 1 and ItemLoot.tier_for_roll(80) == 1 and ItemLoot.tier_for_roll(81) == 2 and ItemLoot.tier_for_roll(96) == 2 and ItemLoot.tier_for_roll(97) == 3, "tier boundaries have no gaps or overlap")
	var unchanged := true
	var originals: Array[float] = []
	for item: ItemData in ItemLoot.POTIONS:
		originals.append(item.amount)
	for kind in 4:
		for tier in 4:
			var item := ItemLoot.make_potion(kind, tier)
			check(item.rarity == tier and is_equal_approx(item.amount, [0.05, 0.10, 0.15, 0.25][tier]) and item.kind != ItemData.Kind.HEAL and item.proportional, "potion type %d tier %d has exact permanent percentage" % [kind, tier])
			check(item.item_name.contains("%d%%" % roundi(item.amount * 100)) and item.tint == ItemLoot.TIER_COLORS[tier], "potion type %d tier %d communicates strength and rarity" % [kind, tier])
		unchanged = unchanged and ItemLoot.POTIONS[kind].amount == originals[kind]
	check(unchanged, "creating potion variants never mutates shared item resources")
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 5611
	second.seed = 5611
	var identical := true
	counts = [0, 0, 0, 0]
	for index in 10000:
		var item := ItemLoot.roll_potion(first)
		counts[item.rarity] += 1
		if index < 100:
			identical = identical and item.item_name == ItemLoot.roll_potion(second).item_name
	check(identical, "chest random sequence is reproducible from its seed")
	var distribution_ok := true
	for tier in 4:
		distribution_ok = distribution_ok and absf(counts[tier] / 10000.0 - [0.50, 0.31, 0.16, 0.03][tier]) < 0.025
	check(distribution_ok, "10000 sampled chest rewards follow the specified distribution")
	await setup_arena()
	arena.player.health_component.current_health = 3
	for kind in 4:
		for tier in 4:
			arena.player.damage_multiplier = 2
			arena.player.speed_multiplier = 1
			arena.player.cooldown_multiplier = 1
			arena.player.pickup_radius = 100
			var item := ItemLoot.make_potion(kind, tier)
			arena.player.collect_item(item)
			var actual: float = [arena.player.damage_multiplier / 2, arena.player.speed_multiplier, 1.0 / arena.player.cooldown_multiplier, arena.player.pickup_radius / 100][kind]
			check(is_equal_approx(actual, 1.0 + item.amount) and arena.player.health_component.current_health == 3, "potion type %d tier %d grants actual percentage without healing" % [kind, tier])
	check(arena.player.inventory.size() == 16, "different potion tiers remain distinct in inventory")
	arena.room_chests[1].locked = false
	arena.player.position = arena.room_chests[1].position + Vector2(0, 12)
	var input := InputEventAction.new()
	input.action = "interact"
	input.pressed = true
	arena._unhandled_input(input)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.set_physics_process(false)
	var drops := get_tree().get_nodes_in_group("pickups")
	check(drops.size() == 1 and drops[0].data.rarity >= 0 and drops[0].data.proportional, "opening a challenge chest drops one tiered stat potion")
	arena._unhandled_input(input)
	check(get_tree().get_nodes_in_group("pickups").size() == 1, "opening the same chest cannot duplicate tier rewards")
	await cleanup()

func test_shops() -> void:
	await setup_arena()
	var seen: Dictionary = {}
	var safe := true
	for seed_value in 100:
		arena.dungeon.rng.seed = seed_value + 1
		arena._roll_shop_offers()
		var unique: Dictionary = {}
		for offer: Dictionary in arena.shop_offers:
			seen[offer.item.item_name] = true
			unique[offer.item] = true
			safe = safe and not offer.item.requires_ranged and offer.item.kind != ItemData.Kind.HEAL and offer.price == arena.shop_price(offer.item) and not offer.sold
		safe = safe and unique.size() == 3
	check(safe, "melee shops roll three distinct compatible items at individual tiered prices")
	check(not seen.has("穿甲弹头") and seen.has("轻质握柄") and seen.has("猎首勋章") and seen.has("寒晶碎片") and seen.has("焦炭印记") and seen.has("贪财口袋"), "all five compatible new perks can appear in melee shops")
	arena.player.position = arena.shop_service.position
	arena.player.coins = 100
	var piercing := ItemLoot.SHOP_PERKS[1]
	arena.shop_offers = [{"item": piercing, "price": 12, "sold": false}]
	check(not arena.buy_shop(0) and arena.player.coins == 100 and arena.player.projectile_pierce == 0, "stale incompatible piercing offer cannot charge a melee player")
	await cleanup()
	await setup_arena(true)
	seen.clear()
	for seed_value in 100:
		arena.dungeon.rng.seed = seed_value + 1
		arena._roll_shop_offers()
		for offer: Dictionary in arena.shop_offers:
			seen[offer.item.item_name] = true
	check(ItemLoot.SHOP_PERKS.all(func(item: ItemData) -> bool: return seen.has(item.item_name)), "all six new perks can appear in ranged shops")
	arena.player.position = arena.shop_service.position
	arena.player.coins = 100
	var purchased := true
	for item: ItemData in ItemLoot.SHOP_PERKS:
		arena.shop_offers = [{"item": item, "price": 12, "sold": false}]
		var coins := arena.player.coins
		purchased = purchased and arena.buy_shop(0) and arena.player.coins == coins - 12 and not arena.buy_shop(0)
		arena.hud.hide_modal()
	check(purchased and arena.player.inventory.size() == 6, "all six perks can be purchased once for the exact listed price")
	check(is_equal_approx(arena.player.cooldown_multiplier, 1.0 / 1.12) and is_equal_approx(arena.player.damage_multiplier, 0.95), "light grip increases real attack rate by 12 percent and reduces damage by 5 percent")
	check(arena.player.projectile_pierce == 1 and is_equal_approx(arena.player.ranged_damage_factor, 0.9), "armor piercing adds one penetration and applies its ranged damage penalty")
	check(is_equal_approx(arena.player.hunter_bonus, 0.2), "headhunter purchase stores 20 percent elite damage bonus")
	check(is_equal_approx(arena.player.weapon_elements[Elements.Type.WATER], 0.1) and is_equal_approx(arena.player.hit_effects().frost_chance, 0.2), "frost shard grants water damage and 20 percent slow chance")
	check(is_equal_approx(arena.player.hit_effects().burn_chance, 0.2) and arena.player.greedy_pouches == 1, "ember mark and greedy pouch purchases enable their actual effects")
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.choose_floor_reward(1)
	await frames(5)
	check(arena.current_floor == 2 and arena.player.projectile_pierce == 1 and arena.player.greedy_pouches == 1 and arena.player.frost_stacks == 1 and arena.player.ember_stacks == 1, "all purchased combat perks persist into the next floor")
	await cleanup()

func spawn_bullet(point: Vector2, pierces: int) -> Bullet:
	var data := preload("res://Data/Weapons/weapon_pistol.tres").duplicate() as WeaponData
	data.bullet_speed = 4000
	data.damage = 2
	var bullet := data.bullet_scene.instantiate() as Bullet
	bullet.setup(data, 1, 0, {}, pierces)
	bullet.position = point + Vector2(0, -7)
	add_child(bullet)
	bullet.set_physics_process(false)
	return bullet

func test_piercing() -> void:
	await setup_arena(true)
	var point := arena.player.position
	var first := enemy_at(point + Vector2(60, 0))
	var second := enemy_at(point + Vector2(110, 0))
	var third := enemy_at(point + Vector2(160, 0))
	await frames()
	var bullet := spawn_bullet(point, 1)
	bullet._physics_process(0.1)
	await frames()
	check(first.health_component.current_health == 98 and second.health_component.current_health == 98 and third.health_component.current_health == 100, "one penetration damages two enemies during a single high-speed sweep")
	check(not is_instance_valid(bullet), "piercing projectile is removed when penetration is exhausted")
	first.queue_free()
	second.queue_free()
	third.queue_free()
	await frames()
	first = enemy_at(point + Vector2(55, 0))
	second = enemy_at(point + Vector2(130, 0))
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(3, 70)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = point + Vector2(90, -7)
	add_child(wall)
	await frames()
	bullet = spawn_bullet(point, 5)
	bullet._physics_process(0.1)
	await frames()
	check(first.health_component.current_health == 98 and second.health_component.current_health == 100 and not is_instance_valid(bullet), "piercing shots still stop at thin walls after hitting an enemy")
	wall.queue_free()
	second.queue_free()
	first.health_component.init_health(100)
	await frames()
	bullet = spawn_bullet(first.position, 5)
	bullet._physics_process(0.0001)
	bullet._physics_process(0.0001)
	check(first.health_component.current_health == 98 and bullet.pierces_left == 4, "a piercing shot cannot repeatedly damage an overlapping enemy")
	bullet.queue_free()
	first.queue_free()
	await frames()
	arena.player.collect_item(ItemLoot.SHOP_PERKS[1])
	var weapon := arena.player.weapon_controller.current_weapon as WeaponRange
	weapon.use_weapon()
	bullet = get_tree().get_first_node_in_group("player_projectiles") as Bullet
	check(is_instance_valid(bullet) and bullet.pierces_left == 1 and is_equal_approx(bullet.damage, weapon.data.damage * 0.9), "manual ranged firing transfers penetration and damage penalty to bullets")
	arena.player.collect_item(ItemLoot.SHOP_PERKS[2])
	check(float(bullet.effects.get("hunter_bonus", 0)) == 0, "an already fired projectile keeps its original perk snapshot")
	await cleanup()

func test_hit_effects() -> void:
	await setup_arena()
	var point := arena.player.position
	var normal := enemy_at(point + Vector2(60, 0))
	var elite := enemy_at(point + Vector2(100, 0), true)
	var boss := make_boss(1)
	arena.player.collect_item(ItemLoot.SHOP_PERKS[2])
	HitEffects.apply(normal, 10, Vector2.ZERO, 0, false, {}, arena.player.hit_effects())
	HitEffects.apply(elite, 10, Vector2.ZERO, 0, false, {}, arena.player.hit_effects())
	var boss_hp := boss.health_component.current_health
	HitEffects.apply(boss, 10, Vector2.ZERO, 0, false, {}, arena.player.hit_effects())
	check(normal.health_component.current_health == 90 and elite.health_component.current_health == 88 and is_equal_approx(boss_hp - boss.health_component.current_health, 12), "headhunter boosts elites and bosses while leaving normal targets unchanged")
	check(Arena.ENEMIES[2].elite and elite.is_in_group("elite_enemies"), "heavy enemies are marked as elites for headhunter")
	normal.health_component.init_health(100)
	normal.element = Elements.Type.FIRE
	HitEffects.apply(normal, 10, Vector2.ZERO, 0, false, {Elements.Type.WATER: 0.1}, {"frost_chance": 1.0})
	check(is_equal_approx(normal.health_component.current_health, 88.5) and normal.slow_time == 1.5 and is_equal_approx(normal.slow_factor, 0.75), "frost applies counter-element water damage and a 25 percent slow")
	boss.apply_slow(1.5, 0.75)
	check(is_equal_approx(boss.status_speed_multiplier(), 0.875), "bosses receive half of the frost slow strength")
	normal._tick_status_effects(1.51)
	check(normal.status_speed_multiplier() == 1.0 and normal.slow_time == 0, "enemy movement fully recovers when frost expires")
	normal.health_component.init_health(100)
	normal.element = Elements.Type.METAL
	HitEffects.apply(normal, 10, Vector2.ZERO, 0, false, {}, {"burn_chance": 1.0})
	normal._tick_status_effects(0.49)
	check(normal.health_component.current_health == 90, "burn has no damage before the first half-second tick")
	normal._tick_status_effects(0.01)
	check(is_equal_approx(normal.health_component.current_health, 87.75), "burn tick deals fire damage with elemental counter multiplier")
	normal._tick_status_effects(1.5)
	check(is_equal_approx(normal.health_component.current_health, 81) and normal.burn_time == 0, "two-second burn totals 60 percent extra damage before elemental matching")
	var labels := get_tree().current_scene.find_children("*", "Label", true, false)
	check(labels.any(func(label: Label) -> bool: return label.text.begins_with("燃 ") and label.get_theme_color("font_color") == Elements.color(Elements.Type.FIRE)), "burn damage numbers use the fire color and burn prefix")
	normal.health_component.init_health(100)
	normal.element = Elements.Type.NONE
	normal.apply_burn(6)
	normal._tick_status_effects(0.3)
	normal.apply_burn(12)
	normal.apply_burn(3)
	normal._tick_status_effects(0.2)
	check(is_equal_approx(normal.health_component.current_health, 97) and normal.burn_time > 1.7, "refreshing burn preserves its tick schedule and strongest damage")
	normal.burn_time = 0
	normal.health_component.current_health = 1
	var kills := arena.kills
	normal.apply_burn(8)
	normal._tick_status_effects(2)
	normal._tick_status_effects(2)
	check(normal.health_component.is_dead and arena.kills == kills + 1, "lethal burn emits exactly one kill reward")
	await cleanup()
	await setup_arena()
	var warden := make_boss(5) as BastionWarden
	var hp := warden.health_component.current_health
	HitEffects.apply(warden, 10, Vector2.ZERO, 0, false, {}, {"frost_chance": 1.0, "burn_chance": 1.0})
	check(warden.health_component.current_health == hp and warden.slow_time == 0 and warden.burn_time == 0, "shielded boss cannot receive frost or burn through its immunity")
	warden.take_hit(9999)
	HitEffects.apply(warden, 1, Vector2.ZERO, 0, false, {}, {"burn_chance": 1.0})
	warden._tick_status_effects(0.5)
	check(is_equal_approx(hp - warden.health_component.current_health, 1.25 + 0.1875), "warden vulnerability amplifies both direct and burn damage")
	warden._activate_shield()
	hp = warden.health_component.current_health
	warden._tick_status_effects(0.5)
	check(warden.health_component.current_health == hp, "restored shield prevents existing burns from bypassing immunity")
	await cleanup()
	await setup_arena()
	var assassin := make_boss(4) as EmberStalker
	assassin._start_slam()
	hp = assassin.health_component.current_health
	check(not HitEffects.apply(assassin, 10, Vector2.ZERO, 0, false, {}, {"frost_chance": 1.0, "burn_chance": 1.0}) and assassin.health_component.current_health == hp and assassin.burn_time == 0 and assassin.slow_time == 0, "blink immunity rejects direct and status effects together")
	await cleanup()

func test_greed() -> void:
	await setup_arena()
	arena.player.collect_item(ItemLoot.SHOP_PERKS[5])
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 1
	var point := arena.dungeon.room_center(1)
	arena._on_enemy_killed(point, 0, 0)
	check(not arena.greed_rewarded_rooms.has(1) and coin_total() == 0, "summoned enemies cannot consume or grant greedy pouch bonus")
	arena._on_enemy_killed(point, 1, 1)
	check(coin_total() == 1 and arena.greed_rewarded_rooms.has(1), "first challenge kill grants one actual bonus coin after base reduction")
	arena._on_enemy_killed(point, 1, 1)
	check(coin_total() == 2, "later kills in the same room only grant normal reduced coins")
	arena.player.collect_item(ItemLoot.SHOP_PERKS[5])
	arena.active_room = 3
	var before := coin_total()
	arena._on_enemy_killed(arena.dungeon.room_center(3), 1, 0)
	check(coin_total() - before == 2, "stacked pouches increase the bonus in a new challenge room")
	arena.active_room = 5
	before = coin_total()
	arena._on_enemy_killed(arena.dungeon.room_center(5), 1, 0)
	check(coin_total() == before, "boss rooms never receive the challenge-only pouch bonus")
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.choose_floor_reward(1)
	await frames(5)
	check(arena.greed_rewarded_rooms.is_empty() and arena.player.greedy_pouches == 2, "next floor resets first-kill eligibility while keeping pouch stacks")
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 1
	before = coin_total()
	arena._on_enemy_killed(arena.dungeon.room_center(1), 1, 0)
	check(coin_total() - before == 2, "pouch bonus can trigger again on the new floor")
	await cleanup()

func test_shop_healing() -> void:
	await setup_arena()
	arena.player.position = arena.shop_service.position
	arena.player.coins = 500
	var prices := [[10, 12, 14, 16, 18], [18, 22, 26, 29, 33], [32, 39, 45, 52, 58]]
	for index in ItemLoot.HEALING_POTIONS.size():
		var potion: ItemData = ItemLoot.HEALING_POTIONS[index]
		for floor_index in 5:
			arena.current_floor = floor_index + 1
			check(arena.shop_price(potion) == prices[index][floor_index], "%s floor %d adds twenty percent of its doubled starting price" % [potion.item_name, floor_index + 1])
		arena.current_floor = 1
		arena.player.health_component.init_health(100)
		arena.player.health_component.current_health = 10
		arena.shop_offers = [{"item": potion, "price": arena.shop_price(potion), "sold": false}]
		var coins := arena.player.coins
		check(arena.buy_shop(0) and arena.player.coins == coins - potion.shop_price and arena.player.health_component.current_health == minf(100, 10 + potion.amount * 100), potion.item_name + " heals its advertised percentage and charges once")
		check(arena.player.inventory.is_empty() and not arena.buy_shop(0), potion.item_name + " is consumed immediately and cannot be bought twice from one slot")
		arena.player.health_component.current_health = 100
		coins = arena.player.coins
		arena.shop_offers = [{"item": potion, "price": arena.shop_price(potion), "sold": false}]
		check(not arena.buy_shop(0) and arena.player.coins == coins, potion.item_name + " cannot waste money at full health")
		arena._spawn_pickup(potion, arena.player.position)
	check(get_tree().get_nodes_in_group("pickups").is_empty(), "shop medicine is never spawned as enemy or chest loot")
	var seen: Dictionary = {}
	for seed_value in 100:
		arena.dungeon.rng.seed = seed_value + 1
		arena._roll_shop_offers()
		for offer: Dictionary in arena.shop_offers:
			seen[offer.item.item_name] = true
	check(ItemLoot.HEALING_POTIONS.all(func(item: ItemData): return seen.has(item.item_name)), "all three medicines appear in the random shop stock")
	await cleanup()

func run() -> void:
	await test_tiers()
	await test_shops()
	await test_piercing()
	await test_hit_effects()
	await test_greed()
	await test_shop_healing()
	print("RESULT: %d/%d item checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
