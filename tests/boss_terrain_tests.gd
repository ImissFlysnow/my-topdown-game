extends Node2D

var arena: Arena
var player: Player
var checks := 0
var failures := 0
var folder := ""

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

func capture(name: String) -> void:
	if folder.is_empty():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + name + ".png")

func terrain(kind: BossTerrain.Kind) -> BossTerrain:
	for attack in get_tree().get_nodes_in_group("boss_terrain"):
		if attack.kind == kind and not attack.is_queued_for_deletion():
			attack.set_physics_process(false)
			return attack
	return null

func cleanup() -> void:
	for attack in get_tree().get_nodes_in_group("enemy_attacks"):
		if attack.has_method("cancel"):
			attack.cancel()
		attack.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames()

func spawn_boss(floor_number: int) -> DungeonBoss:
	arena.current_floor = floor_number
	arena.phase = Arena.Phase.COMBAT
	arena.current_room = 5
	arena.active_room = 5
	player.health_component.init_health(100)
	player.health_component.current_health = 70
	player.invulnerability = 0
	player.slow_time = 0
	player.slow_factor = 1
	player.item_effects.clear_transient()
	player.skills.configure("bunny_decoy", "bunny_charge")
	player.position = arena.dungeon.room_center(5)
	player._update_health_ui()
	arena._spawn_boss(player.position + Vector2(60, 0), Arena.BOSS_DATA[floor_number - 1])
	var result := get_tree().get_first_node_in_group("bosses") as DungeonBoss
	result.set_physics_process(false)
	arena.hud.toast_time = 0
	return result

func test_thorns() -> void:
	var boss := spawn_boss(2) as ThornSovereign
	boss.skill_index = 3
	boss._start_slam()
	var wall := terrain(BossTerrain.Kind.THORNS)
	check(wall != null and boss.casting_skill == 3, "wood Boss has a fourth distinct thorn-wall cast")
	check(wall.regions.size() == 4 and wall.regions[0].size.y == 48 and wall.regions[1].size.x == 48, "two horizontal and two vertical barriers are each exactly two dungeon tiles wide")
	check(wall.regions[0].size.x == wall.room.size.x and wall.regions[1].size.y == wall.room.size.y, "thorn lanes span the complete Boss room")
	player.position = wall.global_position + wall.regions[0].get_center()
	var hp := player.health_component.current_health
	wall._physics_process(0.99)
	check(wall.bodies.is_empty() and player.health_component.current_health == hp, "thorn warning creates neither solid collision nor early damage")
	await capture("2-thorn-warning")
	wall._physics_process(0.02)
	check(wall.bodies.size() == 4 and player.health_component.current_health < hp, "thorn walls become real terrain and hurt after the warning")
	check(wall.bodies[0].get_collision_exceptions().has(player), "player caught by growing thorns can escape instead of being embedded")
	await frames()
	check(not player.test_move(player.global_transform, Vector2(0, 40)), "player caught inside newly grown thorns can actually walk out")
	player.position = Vector2(wall.room.get_center().x, wall.global_position.y + wall.regions[0].position.y - 16)
	wall._physics_process(0.01)
	await frames()
	check(player.test_move(player.global_transform, Vector2(0, 30)), "active thorn terrain physically intercepts player movement")
	var boss_position := boss.position
	boss.position = player.position
	check(not boss.test_move(boss.global_transform, Vector2(0, 30)), "wood Boss can traverse its own thorns and cannot become stuck")
	boss.position = boss_position
	check(not wall.bodies[0].get_collision_exceptions().has(player), "thorn escape exception ends once the player is outside")
	await capture("2-thorn-active")
	wall._physics_process(4.1)
	check(wall.cancelled and wall.bodies.all(func(body: StaticBody2D): return body.collision_layer == 0), "thorn expiry removes all four barriers immediately")
	await cleanup()

func test_water() -> void:
	var boss := spawn_boss(3) as TideArchmage
	boss.skill_index = 3
	boss._start_slam()
	var field := terrain(BossTerrain.Kind.WATER)
	check(boss.skill_name == "水域封场" and field.regions.size() >= 2, "water Boss has a fourth cast with multiple water squares")
	check(field.regions.all(func(region: Rect2): return field.room.encloses(Rect2(region.position + field.position, region.size))), "water squares stay inside the current room")
	player.position = field.position + field.regions[0].get_center()
	var hp := player.health_component.current_health
	field._physics_process(field.warning_time - 0.01)
	check(player.slow_time == 0, "water warning does not slow early")
	field._physics_process(0.02)
	check(player.slow_time > 0 and is_equal_approx(player.slow_factor, 0.55) and player.health_component.current_health == hp, "standing in water slows by forty-five percent without dealing damage")
	player.slow_time = 0
	field._physics_process(1)
	check(player.slow_time == 0.18, "standing in water continuously refreshes slow")
	await capture("3-water-squares")
	player.position = field.room.position + Vector2(10, 10)
	player.slow_time = 0
	field._physics_process(0.1)
	check(player.slow_time == 0 and field.bodies.is_empty(), "leaving water stops refreshing slow and water never blocks movement")
	var old := field
	boss.skill_index = 2
	boss._start_slam()
	field = terrain(BossTerrain.Kind.WATER)
	check(old.cancelled and field != old, "new water cast replaces old pools instead of covering the whole room")
	boss._tick_special_state(0.76)
	boss._tick_special_state(0.01)
	var orbs := get_tree().get_nodes_in_group("enemy_attacks").filter(func(node): return node is EnemyProjectile and not node.is_queued_for_deletion())
	check(orbs.size() == 3 and orbs.all(func(node: EnemyProjectile): return node.speed == 164 and node.homing_turn_rate == 1.5), "water pools accompany all three homing orbs while retaining doubled speed")
	field._physics_process(field.warning_time + 6.1)
	check(field.cancelled, "water squares expire after six active seconds")
	await cleanup()

func test_fire() -> void:
	var boss := spawn_boss(4) as EmberStalker
	var center := arena.dungeon.room_center(5)
	boss._leave_fire(center - Vector2(130, 0), center + Vector2(130, 0))
	var trail := terrain(BossTerrain.Kind.FIRE)
	var count := trail.fire_tiles.size()
	boss._leave_fire(center - Vector2(100, 0), center + Vector2(100, 0))
	check(boss.fire_trail == trail and trail.fire_tiles.size() == count, "overlapping dashes share a single deduplicated fire trail")
	check(trail.fire_tiles.size() > 8, "fast dashes leave continuous fire tiles along the full swept path")
	player.position = (Vector2(trail.fire_tiles.keys()[count / 2]) + Vector2(0.5, 0.5)) * trail.tile_size
	var hp := player.health_component.current_health
	trail._physics_process(0.99)
	check(player.health_component.current_health == hp, "stepping on fire for less than one second does not hurt")
	trail._physics_process(0.01)
	check(player.health_component.current_health == hp - 1, "one full second in fire deals exactly one base health damage")
	player.invulnerability = 0
	trail._physics_process(1)
	check(player.health_component.current_health == hp - 2, "overlapping flames still deal only one damage per second")
	await capture("4-dash-fire-trail")
	player.position = center + Vector2(0, 70)
	trail._physics_process(0.1)
	check(trail.exposure == 0, "leaving the trail resets fire exposure")
	var age := trail.age
	get_tree().paused = true
	trail._physics_process(2)
	get_tree().paused = false
	check(trail.age == age, "pause freezes terrain lifetime and damage timers")
	trail._physics_process(5.1)
	check(trail.cancelled and trail.fire_tiles.is_empty(), "fire tiles disappear after five seconds")
	# Use the actual dash state, rather than only the trail placement helper.
	boss.skill_index = 1
	boss._start_slam()
	boss._tick_special_state(0.4)
	boss._physics_process(1.0 / 60.0)
	check(terrain(BossTerrain.Kind.FIRE) != null, "actual Boss dash movement emits the new fire effect")
	await cleanup()

func test_burst() -> void:
	var boss := spawn_boss(5) as BastionWarden
	var boss_hp := boss.health_component.current_health
	boss.take_hit(99999)
	var burst := terrain(BossTerrain.Kind.SHIELD_BURST)
	check(burst != null and burst.position.is_equal_approx(boss.position), "shield break spawns its explosion at the Boss origin")
	check(is_equal_approx(PI * burst.radius * burst.radius, burst.room.get_area() * 0.5), "explosion circle covers approximately half a room in area")
	check(boss.health_component.current_health == boss_hp, "shield explosion never damages or kills its caster")
	player.position = boss.position
	var hp := player.health_component.current_health
	burst._physics_process(0.99)
	check(player.health_component.current_health == hp and not burst.resolved, "shield explosion always allows one actual second of warning")
	await capture("5-shield-break-warning")
	burst._physics_process(0.01)
	check(is_equal_approx(player.health_component.current_health, hp - burst.damage) and burst.resolved, "explosion damages only when the warning ends")
	hp = player.health_component.current_health
	player.invulnerability = 0
	burst._physics_process(0.1)
	check(player.health_component.current_health == hp, "each broken shield explodes once, not every animation frame")
	await capture("5-shield-break-explosion")
	boss._activate_shield()
	boss.take_hit(99999)
	burst = terrain(BossTerrain.Kind.SHIELD_BURST)
	player.position = burst.room.position + Vector2(8, 8)
	burst._physics_process(1)
	check(player.health_component.current_health == hp, "player outside the circle can safely evade the blast")
	boss._activate_shield()
	boss.take_hit(99999)
	burst = terrain(BossTerrain.Kind.SHIELD_BURST)
	boss._begin_reforge(true)
	check(not burst.cancelled, "rapid phase transition cannot cancel an already-triggered shield explosion")
	boss.phase_index = 3
	boss.state = DungeonBoss.State.CHASE
	boss.take_hit(99999)
	check(burst.cancelled, "Boss death immediately cancels its pending explosion")
	await cleanup()
	check(get_tree().get_nodes_in_group("boss_terrain").is_empty(), "all new terrain and collision nodes are removed after death")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	Global.selected_player = preload("res://Data/Player/player_bunny.tres")
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	player = arena.player
	arena.set_physics_process(false)
	player.set_physics_process(false)
	player.skills.set_physics_process(false)
	player.weapon_controller.set_physics_process(false)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.global_position = arena.dungeon.room_center(5)
	camera.zoom = Vector2.ONE
	arena.dungeon.seal_room(5, true)
	await frames()
	await test_thorns()
	await test_water()
	await test_fire()
	await test_burst()
	arena.queue_free()
	await frames()
	print("RESULT: %d/%d Boss terrain checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
