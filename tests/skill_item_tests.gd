extends Node2D

const PLAYERS = [preload("res://Data/Player/player_bunny.tres"), preload("res://Data/Player/player_cat.tres"), preload("res://Data/Player/player_dog.tres"), preload("res://Data/Player/player_mouse.tres")]
var checks := 0
var failures := 0
var arena: Arena
var player: Player
var skills: SkillController
var perks: SkillItemEffects
var deaths := 0

func _ready() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for index in count:
		await get_tree().process_frame
		await get_tree().physics_frame

func fresh(character: int = 0, active: int = 0, passive: int = 2) -> void:
	get_tree().paused = false
	arena.hud.hide_modal()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	for effect in get_tree().get_nodes_in_group("player_projectiles"):
		effect.queue_free()
	perks.counts.clear()
	perks.battery_acquired = false
	player.inventory.clear()
	player.data = PLAYERS[character]
	player.health_component.init_health(100)
	player.energy = 30
	player.invulnerability = 0
	player.can_move = true
	player.damage_multiplier = 1
	player.speed_multiplier = 1
	player.cooldown_multiplier = 1
	player.crit_chance = 0
	player.weapon_elements.clear()
	player.slow_time = 0
	player.knockback_velocity = Vector2.ZERO
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 1
	player.position = arena.dungeon.room_center(1)
	skills.configure(SkillCatalog.choices(player.data.id, "active")[active].id, SkillCatalog.choices(player.data.id, "passive")[passive].id)
	skills.was_combat = true
	player._reset_energy_charge()

func give(index: int, copies: int = 1) -> void:
	for copy in copies:
		check(player.collect_item(ItemLoot.SKILL_PERKS[index]), "collect %s copy %d" % [ItemLoot.SKILL_PERKS[index].item_name, copy + 1])

func enemy_at(offset: Vector2 = Vector2(45, 0)) -> Enemy:
	var result := Arena.ENEMY_SCENE.instantiate() as Enemy
	result.data = Arena.ENEMIES[0].duplicate() as EnemyData
	result.data.max_health = 10000
	result.data.coins = 0
	result.data.experience = 0
	result.target = player
	result.position = player.position + offset
	arena.actors.add_child(result)
	result.element = Elements.Type.NONE
	result.set_physics_process(false)
	return result

func hit(enemy: Enemy, attack: Dictionary) -> void:
	HitEffects.apply(enemy, attack.multiplier, Vector2.ZERO, 0, false, attack.elements, attack.effects)

func test_limits_and_prices() -> void:
	for index in ItemLoot.SKILL_PERKS.size():
		fresh()
		var item: ItemData = ItemLoot.SKILL_PERKS[index]
		for copy in item.max_stacks:
			check(player.collect_item(item), item.item_name + " permits its advertised copies")
		check(not player.collect_item(item) and perks.count(item.kind) == item.max_stacks, item.item_name + " blocks excess copies")
		check(item.icon != null and FileAccess.file_exists("res://Assets/Items/svg/%s.svg" % item.resource_path.get_file().get_basename()), item.item_name + " has PNG and SVG pixel art")
		arena.current_floor = 1
		check(arena.shop_price(item) == item.shop_price and item.shop_price in range(4, 23), item.item_name + " has a strength-based base price")
		arena.current_floor = 5
		check(arena.shop_price(item) == item.shop_price + 4, item.item_name + " adds only four coins on the last floor")
	arena.current_floor = 1
	fresh(1)
	check(not player.can_collect_item(ItemLoot.SKILL_PERKS[0]), "non-damaging active skills do not waste a capacitor purchase")

func test_energy_and_capacitor() -> void:
	fresh()
	give(4)
	player.energy = 0
	player.record_damage_dealt(1)
	check(is_equal_approx(player.energy_regen_remaining, 0.2), "one crystal reduces the accelerated energy interval to 0.2 seconds")
	player._tick_energy(0.19)
	player.record_damage_dealt(1)
	check(player.energy == 0, "crystal still enforces its damage interval")
	player._tick_energy(0.01)
	player.record_damage_dealt(1)
	check(player.energy == 1, "crystal awards one point on the next actual hit")
	player._tick_energy(40)
	check(player.energy == 1, "idle time never grants crystal energy")
	player.record_damage_dealt(1)
	check(player.energy == 2, "idle time cannot bank multiple energy points")
	give(4)
	check(is_equal_approx(perks.regen_interval(), 1.0 / 6.0), "two crystals add fifty-percent efficiency to the eight-times base rate")
	get_tree().paused = true
	var remaining := player.energy_regen_remaining
	player._tick_energy(5)
	check(player.energy_regen_remaining == remaining, "pausing freezes enhanced energy collection")
	get_tree().paused = false
	fresh(0, 1)
	give(0)
	var enemy := enemy_at()
	check(skills.cast(enemy.position), "moon blade casts with capacitor")
	var effects := get_tree().get_nodes_in_group("player_skill_effects")
	var blade = effects.filter(func(effect): return not effect.is_queued_for_deletion() and effect.kind == "blade").back()
	blade.set_physics_process(false)
	skills.deal(enemy, 1, Elements.Type.NONE, blade.cast_token)
	skills.deal(enemy, 1, Elements.Type.NONE, blade.cast_token)
	check(player.energy == 12, "outbound and return damage share exactly one two-point refund")
	skills.cooldown = 0
	player.energy = 30
	skills.cast(enemy.position)
	var new_token: Dictionary = skills.cast_token
	skills.deal(enemy, 1, Elements.Type.NONE, blade.cast_token)
	check(player.energy == 10, "old projectile never spends the new cast refund")
	skills.deal(enemy, 1, Elements.Type.NONE, new_token)
	check(player.energy == 12, "a separate cast has its own refund")
	fresh(3, 2)
	give(0)
	enemy = enemy_at()
	skills.cast(enemy.position)
	for effect in get_tree().get_nodes_in_group("player_skill_effects"):
		if not effect.is_queued_for_deletion() and effect.kind == "mine":
			effect.set_physics_process(false)
			skills.deal(enemy, 1, Elements.Type.NONE, effect.cast_token)
	check(player.energy == 12, "three mines share one refund per cast")
	var warden := Arena.BOSS_SCENES[4].instantiate() as BastionWarden
	warden.data = Arena.BOSS_DATA[4]
	warden.target = player
	warden.position = player.position + Vector2(100, 0)
	arena.actors.add_child(warden)
	warden.set_physics_process(false)
	warden.state = DungeonBoss.State.REFORGE
	player.energy = 0
	player._reset_energy_charge()
	skills.cast_token = {"refunded": false}
	check(not skills.deal(warden, 1) and player.energy == 0 and not player.energy_charge_started, "immune Boss gives neither passive energy nor capacitor refund")
	warden._activate_shield()
	skills.deal(warden, 1)
	check(player.energy == 2 and player.energy_charge_started, "actual Boss shield damage qualifies for capacitor and energy collection")
	player.restore_energy(99)
	check(player.energy == 30, "all item energy refunds respect three-cell capacity")

func test_buffs_and_shields() -> void:
	fresh()
	give(1)
	for energy in [0, 9, 10, 20, 30]:
		player.energy = energy
		check(is_equal_approx(skills.begin_attack().multiplier, 1 + floori(energy / 10.0) * 0.04), "storage medal counts only full cells at %d energy" % energy)
	fresh(0, 2)
	give(2, 2)
	give(5, 2)
	give(6, 2)
	skills.cast(player.position + Vector2(40, 0))
	check(is_equal_approx(skills.cooldown_factor(), 1.0 / 1.3) and is_equal_approx(skills.speed_factor(), 1.3 * 1.4), "two sigils and ribbons add their item bonuses to the active buff")
	for attack in 3:
		check(is_equal_approx(skills.begin_attack().multiplier, 1.4), "two gauntlets buff ordinary attack %d once" % (attack + 1))
	check(is_equal_approx(skills.begin_attack().multiplier, 1), "gauntlet ends after three attacks")
	perks.tick(1)
	skills.cooldown = 0
	player.energy = 30
	skills.cast(player.position + Vector2(40, 0))
	check(perks.haste_time == 4 and perks.speed_time == 3 and perks.gauntlet_attacks == 3, "repeat casts refresh durations and attack allowance")
	check(is_equal_approx(skills.cooldown_factor(), 1.0 / 1.3), "repeated casts never compound haste")
	skills.tick(4.01)
	check(perks.gauntlet_attacks == 0 and skills.speed_factor() == 1 and skills.cooldown_factor() == 1, "all item buffs expire cleanly")
	fresh()
	give(3, 2)
	check(is_equal_approx(skills.incoming_damage(10, false), 10), "boots do not protect a stationary player")
	perks.record_movement(player.position, player.position)
	check(is_equal_approx(skills.incoming_damage(10, false), 10), "pressing against a wall grants no movement protection")
	perks.record_movement(player.position, player.position + Vector2.RIGHT)
	check(is_equal_approx(skills.incoming_damage(10, false), 8), "two boots reduce damage by twenty percent during actual movement")
	perks.tick(0.11)
	check(is_equal_approx(skills.incoming_damage(10, false), 10), "movement reduction ends when the player stops")
	fresh(2, 1, 0)
	give(7)
	skills.cast(player.position)
	check(skills.shield == 35 and perks.shield == 10, "Dog shield and charm use separate thirty-five and ten-point pools")
	check(skills.incoming_damage(12, false) == 0 and perks.shield == 0 and skills.shield == 33, "shorter-lived charm shield absorbs first and then Dog shield")
	perks.on_cast()
	perks.tick(1)
	perks.on_cast()
	check(perks.shield == 10 and perks.shield_time == 3 and skills.shield == 33 and skills.shield_time == 4, "refreshing charm cannot stack pools or refresh Dog shield time")
	skills.tick(3.01)
	check(perks.shield == 0 and skills.shield == 33 and skills.shield_time > 0, "charm expires without erasing remaining Dog shield")

func test_ring_and_weapons() -> void:
	fresh()
	give(8)
	var enemy := enemy_at()
	var other := enemy_at(Vector2(50, 10))
	for attack_number in 5:
		var attack := skills.begin_attack()
		for pellet in 8:
			hit(enemy, attack)
			hit(other, attack)
	check(perks.ring_hits == 5 and perks.ring_ready, "five attacks count once each across pellets and multiple enemies")
	var surplus := skills.begin_attack()
	hit(enemy, surplus)
	check(perks.ring_hits == 5, "ready ring cannot bank a second charge")
	player.energy = 0
	check(not skills.cast(enemy.position) and perks.ring_ready, "failed cast retains ring charge")
	player.energy = 30
	skills.cast(enemy.position)
	check(player.energy == 22 and not perks.ring_ready and perks.ring_hits == 0, "successful ten-point skill consumes charge and returns two energy")
	hit(other, surplus)
	check(perks.ring_hits == 0, "late pellets from an already-counted attack cannot start another ring cycle")
	# Exercise the actual shotgun spawning path, including shallow-shared tokens.
	Global.selected_weapon = preload("res://Data/Weapons/weapon_xm1014.tres")
	player.weapon_controller.equip_weapon()
	var shotgun := player.weapon_controller.current_weapon as WeaponRange
	shotgun.set_physics_process(false)
	await frames()
	shotgun.use_weapon()
	var pellets := get_tree().get_nodes_in_group("player_projectiles").filter(func(node): return node is Bullet and not node.is_queued_for_deletion())
	for pellet: Bullet in pellets:
		pellet.set_physics_process(false)
		HitEffects.apply(enemy, 1, Vector2.ZERO, 0, false, {}, pellet.effects)
	check(pellets.size() > 1 and perks.ring_hits == 1, "real shotgun pellets share one ring hit")
	for pellet in pellets:
		pellet.queue_free()
	await frames()
	# Exercise an actual melee swing against two overlapping enemies.
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	player.weapon_controller.equip_weapon()
	var sword := player.weapon_controller.current_weapon as WeaponMelee
	sword.set_physics_process(false)
	enemy.position = player.position + Vector2(22, 0)
	other.position = player.position + Vector2(25, 5)
	await frames()
	sword.pivot.global_rotation = 0
	sword.use_weapon()
	check(perks.ring_hits == 2, "real melee swing hitting two enemies adds exactly one ring hit")

func test_passive_badges() -> void:
	for character in 4:
		for passive in 3:
			fresh(character, 0, passive)
			give(9, 2)
			var enemy := enemy_at()
			var valid := false
			match skills.passive_id:
				"bunny_charge":
					skills.charge_ready = true
					valid = is_equal_approx(skills.begin_attack().multiplier, 1.35)
				"bunny_combo":
					skills.combo_target = enemy.get_instance_id()
					skills.combo_count = 3
					valid = is_equal_approx(skills.hit_bonus(enemy, skills.begin_attack().effects), 1.28)
				"bunny_light":
					player.apply_slow(2, 0.5)
					valid = is_equal_approx(player.slow_factor, 0.71)
				"cat_crit":
					valid = is_equal_approx(skills.begin_attack().critical_chance, 0.112)
				"cat_execute":
					enemy.health_component.current_health = 100
					valid = is_equal_approx(skills.hit_bonus(enemy, {}), 1.28)
				"cat_guard":
					skills.no_hit_time = 6
					valid = is_equal_approx(skills.incoming_damage(10, false), 5.8) and skills.no_hit_time == 0
				"dog_bravery":
					valid = is_equal_approx(skills.damage_factor(), 1.042)
				"dog_hide":
					valid = is_equal_approx(skills.incoming_damage(10, true), 7.2) and skills.incoming_damage(10, false) == 10
				"dog_bite":
					skills.attack_serial = 3
					valid = is_equal_approx(skills.begin_attack().multiplier, 1.56)
				"mouse_elements":
					player.weapon_elements[Elements.Type.FIRE] = 0.5
					valid = is_equal_approx(skills.begin_attack().elements[Elements.Type.FIRE], 0.605) and is_equal_approx(skills.elemental_factor(), 1.21)
				"mouse_collect":
					valid = is_equal_approx(skills.pickup_factor(), 1.49) and skills.experience_gain(100) == 121
				"mouse_ambush":
					enemy.slow_time = 1
					valid = is_equal_approx(skills.hit_bonus(enemy, {}), 1.21)
			check(valid, skills.passive_id + " scales percentage magnitude by forty percent without changing triggers")

func test_battery() -> void:
	fresh()
	give(10)
	player.energy = 28
	player.health_component.current_health = 4
	player.slow_time = 2
	var before_deaths := deaths
	player.take_hit(999, Vector2.RIGHT)
	check(not player.health_component.is_dead and player.health_component.current_health == 20 and player.can_move, "enemy lethal attack restores exactly twenty percent max health")
	check(player.energy == 30 and player.invulnerability == 2 and player.slow_time == 0 and player.knockback_velocity == Vector2.ZERO, "revive grants five capped energy and safe two-second recovery")
	check(deaths == before_deaths and arena.phase == Arena.Phase.COMBAT, "revive never emits player death or ends the run")
	check(perks.count(ItemData.Kind.EMERGENCY_BATTERY) == 0 and not player.inventory.has("应急电池") and not player.collect_item(ItemLoot.SKILL_PERKS[10]), "battery is consumed and cannot be purchased again in the run")
	check(not player.take_hit(999) and player.health_component.current_health == 20, "revive protection blocks follow-up lethal hits")
	player.invulnerability = 0
	player.take_hit(999)
	check(player.health_component.is_dead and deaths == before_deaths + 1, "a second lethal hit after protection ends kills normally")
	await frames()
	fresh()
	give(10)
	player.health_component.current_health = 8
	player.energy = 0
	player.take_hit(2)
	check(player.health_component.current_health == 6 and player.energy == 0 and perks.count(ItemData.Kind.EMERGENCY_BATTERY) == 1, "nonlethal damage does not trigger battery")
	player.health_component.take_damage(1)
	check(perks.count(ItemData.Kind.EMERGENCY_BATTERY) == 1 and player.health_component.current_health == 5, "direct event damage cannot consume battery")
	player.invulnerability = 0
	player.take_hit(5)
	check(player.health_component.current_health == 20 and player.energy == 5, "exactly lethal damage grants the requested five energy")

func test_shop_and_gold() -> void:
	fresh()
	arena.phase = Arena.Phase.EXPLORATION
	player.position = arena.shop_service.position
	player.coins = 20
	arena.shop_refreshes = 0
	arena._roll_shop_offers()
	var previous: Array = arena.shop_offers.map(func(offer: Dictionary): return offer.item)
	check(arena.refresh_shop() and player.coins == 20 and arena.shop_refresh_cost() == 1, "first refresh is free")
	check(arena.shop_offers.all(func(offer: Dictionary): return offer.item not in previous), "refresh replaces all three previous offers when alternatives exist")
	check(arena.refresh_shop() and player.coins == 19 and arena.shop_refresh_cost() == 2, "second refresh costs one coin")
	check(arena.refresh_shop() and player.coins == 17 and arena.shop_refresh_cost() == 3, "third refresh costs two coins")
	arena.hud.hide_modal()
	arena.hud.show_shop()
	check(arena.shop_refresh_cost() == 3, "closing and reopening cannot reset refresh cost")
	player.coins = 2
	var old_offers := arena.shop_offers.duplicate()
	check(not arena.refresh_shop() and player.coins == 2 and arena.shop_refreshes == 3 and old_offers == arena.shop_offers, "insufficient gold preserves stock, wallet and refresh count")
	get_tree().paused = false
	arena.phase = Arena.Phase.COMBAT
	check(not arena.refresh_shop(), "combat cannot refresh shop")
	arena.phase = Arena.Phase.EXPLORATION
	player.position = arena.dungeon.room_center(1)
	check(not arena.refresh_shop(), "remote shop refresh is blocked")
	player.position = arena.shop_service.position
	player.coins = 100
	arena.shop_offers = [{"item": ItemLoot.SKILL_PERKS[8], "price": 12, "sold": false}]
	check(arena.buy_shop(0) and player.coins == 88 and perks.count(ItemData.Kind.COMBO_RING) == 1, "new ring purchase charges the displayed price")
	arena.shop_offers = [{"item": ItemLoot.SKILL_PERKS[8], "price": 12, "sold": false}]
	check(not arena.buy_shop(0) and player.coins == 88, "stale capped offers cannot charge coins")
	arena._roll_shop_offers()
	check(arena.shop_offers.all(func(offer: Dictionary): return offer.item.kind != ItemData.Kind.COMBO_RING), "maxed items are removed from future stock")
	arena.hud.hide_modal()
	arena.phase = Arena.Phase.REWARD
	arena.awaiting_reward = true
	arena.choose_floor_reward(1)
	await frames(4)
	check(arena.current_floor == 2 and arena.shop_refreshes == 0 and perks.count(ItemData.Kind.COMBO_RING) == 1, "new floor resets refresh fees and preserves owned items")
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	await frames()
	arena.coin_drop_remainder = 0
	for index in 100:
		arena._on_enemy_killed(arena.dungeon.room_center(1), 0, 1)
	var total := 0
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.set_physics_process(false)
		if pickup.data.kind == ItemData.Kind.COIN:
			total += int(pickup.data.amount)
	check(total == 65 and is_zero_approx(arena.coin_drop_remainder), "100 base coins award 65: exactly thirty percent more than previous fifty")

func run() -> void:
	Global.selected_player = PLAYERS[0]
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	player = arena.player
	skills = player.skills
	perks = player.item_effects
	arena.set_physics_process(false)
	player.set_physics_process(false)
	player.weapon_controller.set_physics_process(false)
	skills.set_physics_process(false)
	EventBus.on_player_died.connect(func(): deaths += 1)
	await frames()
	test_limits_and_prices()
	test_energy_and_capacitor()
	test_buffs_and_shields()
	await test_ring_and_weapons()
	test_passive_badges()
	await test_battery()
	await test_shop_and_gold()
	get_tree().paused = false
	arena.queue_free()
	await frames()
	print("RESULT: %d/%d skill item checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
