extends Node2D
class_name Arena

enum Phase { EXPLORATION, COMBAT, FLOOR_CLEARED, REWARD, FINISHED }
enum RoomState { UNVISITED, ACTIVE, CLEARED }
const ENEMY_SCENE = preload("res://Scene/Enemies/enemy.tscn")
const BOSS_SCENE = preload("res://Scene/Enemies/boss.tscn")
const BOSS_SCENES: Array[PackedScene] = [BOSS_SCENE, preload("res://Scene/Enemies/boss_summoner.tscn"), preload("res://Scene/Enemies/boss_ranged.tscn"), preload("res://Scene/Enemies/boss_assassin.tscn"), preload("res://Scene/Enemies/boss_warden.tscn")]
const BOSS_DATA: Array[EnemyData] = [preload("res://Data/Enemies/boss.tres"), preload("res://Data/Enemies/thorn_sovereign.tres"), preload("res://Data/Enemies/tide_archmage.tres"), preload("res://Data/Enemies/ember_stalker.tres"), preload("res://Data/Enemies/bastion_warden.tres")]
const BOSS_HINTS = ["躲避蓄力重击，半血后进入狂暴", "井字荆棘封路 · 预警后生长 · 清理召唤物", "水块持续减速 · 离开水面躲避追踪弹", "突进留下火径 · 连续踩火 1 秒扣 1 生命", "破盾后远离自爆圆 · 失甲反击 · 三阶段重铸"]
const ENEMIES: Array[EnemyData] = [preload("res://Data/Enemies/slime.tres"), preload("res://Data/Enemies/runner.tres"), preload("res://Data/Enemies/brute.tres")]
const EXPERIENCE_ITEM: ItemData = preload("res://Data/Items/experience.tres")
const COIN_ITEM: ItemData = preload("res://Data/Items/coin.tres")
const HEAL_ITEM: ItemData = preload("res://Data/Items/heal.tres")
const UPGRADES: Array[ItemData] = [preload("res://Data/Items/damage.tres"), preload("res://Data/Items/speed.tres"), preload("res://Data/Items/attack_speed.tres"), preload("res://Data/Items/magnet.tres")]
@export var arena_cursor: Texture2D
@export_range(1, 5) var floor_count: int = 5
@export_range(10, 100) var enemy_limit: int = 55
@export var map_seed: int = 0
@export_range(0.0, 1.0, 0.05) var coin_reward_multiplier: float = 0.65
@onready var dungeon: DungeonGenerator = $Dungeon
@onready var actors: Node2D = $Actors
var player: Player
var hud: BattleHUD
var phase: Phase = Phase.EXPLORATION
var current_floor: int = 1
var current_room: int = 0
var active_room: int = -1
var room_states: Array[int] = []
var cleared_challenges: int = 0
var kills: int = 0
var coin_drop_remainder: float = 0.0
var greed_rewarded_rooms: Dictionary[int, bool] = {}
var elapsed: float = 0.0
var run_seed: int = 0
var changing_scene := false
var awaiting_reward := false
var floor_clear_time: float = -1
var room_chests: Dictionary[int, LootChest] = {}
var shop_service: RoomService
var event_service: RoomService
var exit_service: RoomService
var shop_offers: Array[Dictionary] = []
var shop_refreshes: int = 0
var event_kind: int = 0
var event_resolved := false

func _ready() -> void:
	Cursor.sprite.texture = arena_cursor
	dungeon.generate(map_seed)
	run_seed = dungeon.actual_seed
	EventBus.on_player_health_updated.connect(_on_player_health_updated)
	EventBus.on_player_died.connect(_on_player_died)
	EventBus.on_enemy_killed.connect(_on_enemy_killed)
	EventBus.on_inventory_updated.connect(_on_inventory_updated)
	EventBus.on_item_collected.connect(_on_item_collected)
	load_game_selection()
	_setup_floor()
	hud = BattleHUD.new()
	hud.arena = self
	add_child(hud)
	hud.toast("第 1 层 · 清理三间挑战房，解锁 Boss · 鼠标左键攻击")

func load_game_selection() -> void:
	if not Global.selected_player:
		Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	if not Global.selected_weapon:
		Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	player = Global.get_player().instantiate() as Player
	player.data = Global.selected_player
	player.arena = self
	player.position = dungeon.spawn_position
	actors.add_child(player)
	player.weapon_controller.equip_weapon()
	var loadout := Global.get_skill_loadout(player.data.id)
	player.skills.configure(loadout.active, loadout.passive)
	_configure_camera()

func _configure_camera() -> void:
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = dungeon.grid_size.x * dungeon.cell_size
	camera.limit_bottom = dungeon.grid_size.y * dungeon.cell_size
	camera.reset_smoothing()

func _setup_floor() -> void:
	room_states.assign([RoomState.CLEARED, RoomState.UNVISITED, RoomState.UNVISITED, RoomState.UNVISITED, RoomState.UNVISITED, RoomState.UNVISITED])
	room_chests.clear()
	cleared_challenges = 0
	current_room = 0
	active_room = -1
	phase = Phase.EXPLORATION
	awaiting_reward = false
	floor_clear_time = -1
	event_resolved = false
	greed_rewarded_rooms.clear()
	event_kind = dungeon.rng.randi_range(0, 2)
	for index in [1, 3, 4]:
		var chest := LootChest.new()
		chest.room_id = index
		chest.price = 0
		chest.locked = true
		chest.target = player
		chest.position = dungeon.room_center(index) + Vector2(55, -35)
		actors.add_child(chest)
		room_chests[index] = chest
	shop_service = _create_service(RoomService.Kind.SHOP, 0)
	event_service = _create_service(RoomService.Kind.EVENT, 2)
	exit_service = null
	shop_refreshes = 0
	_roll_shop_offers()
	dungeon.seal_room(5, true)

func shop_price(item: ItemData) -> int:
	if item.kind == ItemData.Kind.SHOP_HEALING:
		# Each floor adds 20% of the first-floor price, rounded up to whole coins.
		return ceili(item.shop_price * (current_floor + 4) / 5.0)
	return item.shop_price + current_floor - 1

func _roll_shop_offers(avoid_previous: bool = false) -> void:
	var stock: Array[ItemData] = []
	var catalog: Array[ItemData] = []
	catalog.append_array(UPGRADES)
	catalog.append_array(ItemLoot.SHOP_PERKS)
	catalog.append_array(ItemLoot.SKILL_PERKS)
	catalog.append_array(ItemLoot.HEALING_POTIONS)
	var previous: Array[ItemData] = []
	for offer: Dictionary in shop_offers:
		previous.append(offer.item)
	for item: ItemData in catalog:
		if item.kind == ItemData.Kind.SHOP_HEALING or player.can_collect_item(item):
			stock.append(item)
	if avoid_previous:
		var alternatives: Array[ItemData] = []
		for item: ItemData in stock:
			if item not in previous:
				alternatives.append(item)
		if alternatives.size() >= 3:
			stock = alternatives
	shop_offers.clear()
	for slot in mini(3, stock.size()):
		var item: ItemData = stock.pop_at(dungeon.rng.randi_range(0, stock.size() - 1))
		shop_offers.append({"item": item, "price": shop_price(item), "sold": false})

func shop_refresh_cost() -> int:
	return shop_refreshes

func refresh_shop() -> bool:
	if not is_instance_valid(shop_service) or not shop_service.nearby() or player.health_component.is_dead or phase not in [Phase.EXPLORATION, Phase.FLOOR_CLEARED]:
		return false
	var cost := shop_refresh_cost()
	if player.coins < cost:
		hud.toast("金币不足，无法刷新")
		return false
	player.coins -= cost
	shop_refreshes += 1
	_roll_shop_offers(true)
	hud.update_inventory()
	hud.show_shop()
	return true

func _create_service(kind: RoomService.Kind, index: int) -> RoomService:
	var service := RoomService.new()
	service.kind = kind
	service.target = player
	service.position = dungeon.room_center(index)
	actors.add_child(service)
	return service

func _physics_process(delta: float) -> void:
	if phase == Phase.FINISHED or changing_scene:
		return
	elapsed += delta
	var room := dungeon.room_at_world(player.global_position)
	current_room = room
	if phase == Phase.EXPLORATION:
		var entered := dungeon.room_at_world(player.global_position, 2)
		if entered >= 0 and room_states[entered] == RoomState.UNVISITED:
			if dungeon.room_types[entered] == DungeonGenerator.RoomType.CHALLENGE:
				_begin_combat_room(entered)
			elif entered == 5 and cleared_challenges == 3:
				_begin_combat_room(5)
	elif phase == Phase.COMBAT:
		if get_tree().get_nodes_in_group("enemies").is_empty() and get_tree().get_nodes_in_group("spawn_markers").is_empty():
			_complete_active_room()
	elif phase == Phase.FLOOR_CLEARED and floor_clear_time >= 0:
		floor_clear_time -= delta
		if floor_clear_time <= 0:
			floor_clear_time = -1
			open_floor_rewards()

func enemy_health_multiplier() -> float:
	return 1.0 + (current_floor - 1) * 0.45

func enemy_damage_multiplier() -> float:
	return 1.0 + (current_floor - 1) * 0.25

func _begin_combat_room(index: int) -> void:
	if phase != Phase.EXPLORATION or room_states[index] != RoomState.UNVISITED:
		return
	if index == 5 and cleared_challenges != 3:
		return
	active_room = index
	current_room = index
	room_states[index] = RoomState.ACTIVE
	phase = Phase.COMBAT
	dungeon.seal_room(index, true)
	if index == 5:
		var marker := SpawnMarker.new()
		marker.position = dungeon.room_center(5) + Vector2(70, 0)
		marker.data = BOSS_DATA[current_floor - 1]
		marker.remaining = 1.3
		marker.finished.connect(_spawn_boss)
		actors.add_child(marker)
		hud.toast("%s · %s" % [marker.data.enemy_name, BOSS_HINTS[current_floor - 1]])
	else:
		var ordinal := [1, 3, 4].find(index)
		var count := mini(enemy_limit, 4 + current_floor * 2 + ordinal)
		for number in count:
			var marker := SpawnMarker.new()
			marker.position = dungeon.room_spawn_position(index, player.global_position)
			var roll := dungeon.rng.randf()
			var kind := 0
			if roll > 0.55:
				kind = 1
			if current_floor >= 2 and roll > 0.8:
				kind = 2
			marker.data = ENEMIES[kind]
			marker.remaining = 0.9 + number * 0.06
			var element := marker.data.element if marker.data.element != Elements.Type.NONE else dungeon.rng.randi_range(1, 5)
			marker.finished.connect(_spawn_enemy.bind(index, element))
			actors.add_child(marker)
		hud.toast("挑战房 · 一波 %d 只敌人 · 清怪后解锁免费宝箱" % count)

func _spawn_enemy(point: Vector2, enemy_data: EnemyData, index: int = -1, element: int = Elements.Type.NONE) -> void:
	if phase == Phase.FINISHED or changing_scene:
		return
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data = enemy_data
	enemy.health_scale = enemy_health_multiplier()
	enemy.damage_scale = enemy_damage_multiplier()
	enemy.move_speed_scale = 1.0 + (current_floor - 1) * 0.06
	enemy.position = point
	enemy.target = player
	enemy.dungeon = dungeon
	enemy.room_id = index
	enemy.element = element
	if index >= 0:
		enemy.room_bounds = dungeon.room_world_rect(index, 18)
	actors.add_child(enemy)

func _spawn_boss(point: Vector2, _data: EnemyData) -> void:
	if phase != Phase.COMBAT or active_room != 5:
		return
	var boss := BOSS_SCENES[current_floor - 1].instantiate() as DungeonBoss
	boss.position = point
	boss.target = player
	boss.dungeon = dungeon
	boss.room_id = 5
	boss.element = current_floor
	boss.floor_number = current_floor
	# Boss resources already encode the exact doubling between floors.
	# Only normal enemies and summons use their separate health scaling.
	boss.health_scale = 1.0
	boss.damage_scale = enemy_damage_multiplier()
	boss.room_bounds = dungeon.room_world_rect(5, 40)
	actors.add_child(boss)

func _complete_active_room() -> void:
	if active_room < 0 or room_states[active_room] != RoomState.ACTIVE:
		return
	var index := active_room
	room_states[index] = RoomState.CLEARED
	dungeon.seal_room(index, false)
	active_room = -1
	if index == 5:
		phase = Phase.FLOOR_CLEARED
		for attack in get_tree().get_nodes_in_group("enemy_attacks"):
			attack.queue_free()
		awaiting_reward = true
		floor_clear_time = 0.95
		exit_service = _create_service(RoomService.Kind.EXIT, 5)
		hud.toast("本层通关！选择强化后进入下一层，也可以先返回探索")
	else:
		cleared_challenges += 1
		room_chests[index].locked = false
		phase = Phase.EXPLORATION
		if cleared_challenges == 3:
			dungeon.seal_room(5, false)
			hud.toast("三间挑战房已完成 · Boss 房解锁！")
		else:
			hud.toast("挑战完成 %d/3 · 宝箱已解锁" % cleared_challenges)

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.FINISHED or phase == Phase.REWARD or changing_scene:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		for chest: LootChest in room_chests.values():
			if chest.can_open():
				if chest.try_open():
					_spawn_pickup(ItemLoot.roll_potion(dungeon.rng), chest.global_position + Vector2(0, 12))
				return
		if phase == Phase.COMBAT:
			return
		if is_instance_valid(exit_service) and exit_service.nearby():
			open_floor_rewards()
		elif shop_service.nearby():
			hud.show_shop()
		elif event_service.nearby():
			if event_resolved:
				hud.toast("本层事件已经结束")
			else:
				hud.show_event()

func buy_shop(index: int) -> bool:
	if index < 0 or index >= shop_offers.size() or not shop_service.nearby() or phase not in [Phase.EXPLORATION, Phase.FLOOR_CLEARED]:
		return false
	var offer := shop_offers[index]
	if offer.sold or player.coins < int(offer.price):
		hud.toast("商品已售出或金币不足")
		return false
	if not player.collect_item(offer.item):
		hud.toast("无法购买该道具")
		return false
	player.coins -= int(offer.price)
	offer.sold = true
	shop_offers[index] = offer
	hud.update_inventory()
	hud.show_shop()
	return true

func resolve_event(option: int) -> bool:
	if event_resolved or not event_service.nearby() or option < 0 or option > 1 or phase not in [Phase.EXPLORATION, Phase.FLOOR_CLEARED]:
		return false
	var healing_choice := (event_kind in [0, 1] and option == 1) or (event_kind == 2 and option == 0)
	if healing_choice and player.health_component.current_health >= player.health_component.max_health:
		hud.toast("生命已满，可以选择另一项或稍后再来")
		return false
	if event_kind == 0:
		if option == 0:
			if player.health_component.current_health <= 2:
				hud.toast("生命不足，无法献祭")
				return false
			player.health_component.take_damage(2)
			player.damage_multiplier += 0.3
		else:
			player.health_component.heal(2)
	elif event_kind == 1:
		if option == 0:
			if player.coins < 8:
				hud.toast("需要 8 金币")
				return false
			player.coins -= 8
			player.collect_item(UPGRADES[dungeon.rng.randi_range(0, 3)])
		else:
			player.health_component.heal(1)
	else:
		if option == 0:
			player.health_component.heal(3)
		else:
			player.cooldown_multiplier = maxf(0.25, player.cooldown_multiplier * 0.9)
	event_resolved = true
	event_service.resolved = true
	room_states[2] = RoomState.CLEARED
	hud.hide_modal()
	hud.update_inventory()
	hud.toast("事件完成 · 每层事件只能领取一次")
	return true

func open_floor_rewards() -> void:
	if not awaiting_reward or phase == Phase.COMBAT or phase == Phase.FINISHED:
		return
	phase = Phase.REWARD
	hud.show_floor_rewards()

func defer_floor_reward() -> void:
	if not awaiting_reward:
		return
	phase = Phase.FLOOR_CLEARED
	floor_clear_time = -1
	hud.hide_modal()
	hud.toast("可继续探索本层 · 到 Boss 房传送门旁按 E 选择强化")

func choose_floor_reward(kind: int, element: int = Elements.Type.NONE) -> bool:
	if phase != Phase.REWARD or not awaiting_reward or kind < 0 or kind > 2:
		return false
	if kind == 2 and (element < 1 or element > 5):
		return false
	awaiting_reward = false
	if kind == 0:
		player.health_component.max_health += 3
		player.damage_multiplier += 0.15
		player.speed_multiplier = minf(1.75, player.speed_multiplier + 0.05)
		player._update_health_ui()
	elif kind == 1:
		player.cooldown_multiplier = maxf(0.25, player.cooldown_multiplier * 0.85)
	else:
		player.weapon_elements[element] = player.weapon_elements.get(element, 0.0) + 0.35
	# Collect XP and coins so progression is not lost on changing floors.
	for pickup: Pickup in get_tree().get_nodes_in_group("pickups"):
		if not pickup.collected and pickup.data.kind <= ItemData.Kind.COIN:
			pickup.collected = true
			player.collect_item(pickup.data)
			pickup.queue_free()
	hud.hide_modal()
	if current_floor >= floor_count:
		_finish_run(true)
	else:
		advance_floor.call_deferred()
	return true

func advance_floor() -> void:
	if awaiting_reward or phase != Phase.REWARD or current_floor >= floor_count:
		return
	player.skills.clear_transient()
	for child in actors.get_children():
		if child != player:
			actors.remove_child(child)
			child.queue_free()
	for projectile in get_tree().get_nodes_in_group("player_projectiles"):
		projectile.queue_free()
	current_floor += 1
	dungeon.generate(run_seed + (current_floor - 1) * 104729)
	player.global_position = dungeon.spawn_position
	player.velocity = Vector2.ZERO
	player.knockback_velocity = Vector2.ZERO
	player.slow_time = 0
	player.slow_factor = 1
	player.invulnerability = 0.5
	_setup_floor()
	_configure_camera()
	hud.update_inventory()
	hud.update_health(player.health_component.current_health, player.health_component.max_health)
	hud.toast("进入第 %d / %d 层 · 敌人生命与伤害提升" % [current_floor, floor_count])

func _spawn_pickup(item: ItemData, point: Vector2, amount: float = -1) -> void:
	# Medicine is purchased in shops or granted by events, never dropped.
	if item.kind in [ItemData.Kind.HEAL, ItemData.Kind.SHOP_HEALING]:
		return
	var pickup := Pickup.new()
	pickup.data = item
	if amount > 0:
		pickup.data = item.duplicate() as ItemData
		pickup.data.amount = amount
	pickup.target = player
	pickup.dungeon = dungeon
	if not dungeon.is_floor(point):
		point = dungeon.cell_to_world(dungeon.nearest_floor_cell(dungeon.world_to_cell(point)))
	pickup.position = point
	actors.add_child(pickup)

func _on_enemy_killed(point: Vector2, experience_amount: int, coin_amount: int) -> void:
	kills += 1
	if experience_amount > 0:
		_spawn_pickup(EXPERIENCE_ITEM, point + Vector2(-7, 0), experience_amount)
	var dropped_coins := 0
	if coin_amount > 0:
		var scaled_coins := coin_amount * coin_reward_multiplier + coin_drop_remainder
		dropped_coins = floori(scaled_coins + 0.000001)
		coin_drop_remainder = maxf(0, scaled_coins - dropped_coins)
	if phase == Phase.COMBAT and active_room in [1, 3, 4] and dungeon.room_at_world(point) == active_room and (experience_amount > 0 or coin_amount > 0) and not greed_rewarded_rooms.has(active_room):
		greed_rewarded_rooms[active_room] = true
		dropped_coins += player.greedy_pouches
	if dropped_coins > 0:
		_spawn_pickup(COIN_ITEM, point + Vector2(7, 0), dropped_coins)
	_on_inventory_updated()

func _on_player_health_updated(current: float, maximum: float) -> void:
	if is_instance_valid(hud):
		hud.update_health(current, maximum)

func _on_inventory_updated() -> void:
	if is_instance_valid(hud):
		hud.update_inventory()

func _on_item_collected(message: String) -> void:
	if is_instance_valid(hud):
		hud.toast(message)

func _on_player_died() -> void:
	_finish_run.call_deferred(false)

func _finish_run(victory: bool) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	player.can_move = false
	hud.show_modal("五层地牢通关！" if victory else "本次探索结束", "第 %d 层 · 击杀 %d · 等级 %d\n存活 %d 秒 · 金币 %d" % [current_floor, kills, player.level, int(elapsed), player.coins], false)

func restart_run() -> void:
	if changing_scene:
		return
	changing_scene = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_selection() -> void:
	if changing_scene:
		return
	changing_scene = true
	get_tree().paused = false
	Transition.transition_to("res://Scene/ui/CharacterSelection/character_selection.tscn")
