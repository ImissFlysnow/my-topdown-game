extends Node2D

var checks := 0
var failures := 0
var arena: Arena
var player: Player
var skills: SkillController
var folder := ""
const PLAYERS = [preload("res://Data/Player/player_bunny.tres"), preload("res://Data/Player/player_cat.tres"), preload("res://Data/Player/player_dog.tres"), preload("res://Data/Player/player_mouse.tres")]

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
		await get_tree().process_frame
		await get_tree().physics_frame

func capture(name: String) -> void:
	if folder.is_empty():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + name + ".png")

func enemy_at(offset: Vector2 = Vector2(45, 0)) -> Enemy:
	var enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
	enemy.data = Arena.ENEMIES[0].duplicate() as EnemyData
	enemy.data.max_health = 10000
	enemy.data.coins = 0
	enemy.data.experience = 0
	enemy.target = player
	enemy.position = player.position + offset
	enemy.element = Elements.Type.NONE
	arena.actors.add_child(enemy)
	enemy.element = Elements.Type.NONE
	enemy.set_physics_process(false)
	return enemy

func setup(character: int, active: int, passive: int) -> void:
	player.data = PLAYERS[character]
	var a: String = SkillCatalog.choices(player.data.id, "active")[active].id
	var p: String = SkillCatalog.choices(player.data.id, "passive")[passive].id
	skills.configure(a, p)
	skills.was_combat = true
	player.energy = 30
	player.invulnerability = 0
	player.knockback_velocity = Vector2.ZERO
	player.weapon_elements.clear()
	player.slow_time = 0
	player.slow_factor = 1
	player.damage_multiplier = 1
	player.crit_chance = 0
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 1
	player.position = arena.dungeon.room_center(1)
	skills.last_position = player.position

func test_catalog() -> void:
	var ids := {}
	for data: PlayerData in PLAYERS:
		check(SkillCatalog.choices(data.id, "active").size() == 3 and SkillCatalog.choices(data.id, "passive").size() == 3, data.id + " has three active and three passive choices")
		for kind in ["active", "passive"]:
			for entry in SkillCatalog.choices(data.id, kind):
				check(not ids.has(entry.id) and SkillCatalog.icon(entry.id) != null and FileAccess.file_exists("res://Assets/Skills/svg/%s.svg" % entry.id), entry.id + " has unique data, SVG and PNG")
				ids[entry.id] = true
				if kind == "active":
					check(entry.cost in [10, 20, 30] and entry.cooldown > 0, entry.id + " fits three-cell energy capacity")
	check(InputMap.has_action("active_skill") and InputMap.action_get_events("active_skill")[0].physical_keycode == KEY_Q, "Q is bound to the active skill action")

func test_actives() -> void:
	for character in 4:
		for active in 3:
			setup(character, active, 2)
			var enemy := enemy_at()
			await frames()
			var entry := SkillCatalog.find(skills.active_id)
			var hp := player.health_component.current_health
			check(skills.cast(enemy.global_position), entry.id + " casts in combat")
			check(player.energy == 30 - int(entry.cost) and skills.cooldown > 0, entry.id + " consumes its exact energy and starts cooldown")
			var energy := player.energy
			check(not skills.cast(enemy.global_position) and player.energy == energy, entry.id + " rejects cooldown spam without spending")
			match skills.active_id:
				"bunny_dash", "dog_charge":
					skills.tick(0.1)
					check(enemy.health_component.current_health < 10000 and player.position.x > arena.dungeon.room_center(1).x, entry.id + " moves and damages its swept path")
					if skills.active_id == "dog_charge":
						check(enemy.control_time > 0, "charge stuns ordinary enemies")
				"bunny_blade":
					var effect = get_tree().get_nodes_in_group("player_skill_effects").back()
					effect._physics_process(0.12)
					effect._physics_process(0.1)
					var damage := 10000 - enemy.health_component.current_health
					check(is_equal_approx(damage, 8), "moon blade damages a target only once on its outward pass")
					effect._physics_process(0.23)
					effect._physics_process(0.12)
					check(enemy.health_component.current_health <= 9984, "moon blade can hit the same target again on return")
				"bunny_decoy":
					check(skills.speed_factor() == 1.3 and skills.lure_for(enemy) == arena.dungeon.room_center(1), "decoy lures ordinary enemies and grants timed movement speed")
				"cat_blink":
					check(player.position.x > arena.dungeon.room_center(1).x and player.invulnerability >= 0.25, "blink moves and grants short invulnerability")
					check(skills.begin_attack().critical_chance == 1 and skills.begin_attack().critical_chance == 0, "blink guarantees exactly the next ordinary attack's crit")
				"cat_mark":
					check(is_equal_approx(skills.hit_bonus(enemy, {}), 1.25), "mark amplifies the selected ordinary target by 25 percent")
				"cat_smoke":
					var effect = get_tree().get_nodes_in_group("player_skill_effects").back()
					effect._physics_process(0.1)
					check(enemy.slow_time > 0 and is_equal_approx(enemy.slow_factor, 0.7) and effect.projectile_speed_factor(enemy.position) == 0.65, "smoke slows enemies and enemy projectiles")
				"dog_roar":
					check(enemy.control_time > 0 and enemy.frightened and skills.damage_factor() > 1 and enemy.health_component.current_health < 10000, "roar damages, fears and grants timed damage")
				"dog_shield":
					check(is_equal_approx(skills.shield, player.health_component.max_health * 0.35), "barrier grants a 35 percent temporary shield")
					player.take_hit(1)
					check(player.health_component.current_health == hp and player.knockback_velocity == Vector2.ZERO, "shield absorbs damage and knockback without healing")
					skills.tick(4)
					check(skills.shield == 0, "temporary shield expires after four seconds")
				"mouse_bomb":
					var effect = get_tree().get_nodes_in_group("player_skill_effects").back()
					effect._physics_process(0.36)
					check(is_equal_approx(enemy.health_component.current_health, 9980), "default earth bomb deals pure 250 percent skill damage without a duplicate physical component")
				"mouse_vortex":
					var effect = get_tree().get_nodes_in_group("player_skill_effects").back()
					for pulse in 3:
						effect._physics_process(0.6)
					check(is_equal_approx(enemy.health_component.current_health, 9980.8), "vortex delivers exactly three pulses totaling 240 percent skill damage")
				"mouse_mines":
					var mines := get_tree().get_nodes_in_group("player_skill_effects").filter(func(node): return not node.is_queued_for_deletion())
					check(mines.size() == 3, "mine array creates exactly three mines")
					var mine = mines[0]
					enemy.position = mine.position
					mine._physics_process(0.31)
					check(mine.exploded and enemy.health_component.current_health < 10000 and enemy.slow_time > 0, "armed mine explodes on contact and slows its target")
			check(player.health_component.current_health <= hp, entry.id + " never restores health")
			skills.clear_transient()
			enemy.queue_free()
			await frames()

func test_passives() -> void:
	setup(0, 0, 0)
	var enemy := enemy_at()
	await frames()
	skills.movement_charge = 160
	skills.tick(0.01)
	check(is_equal_approx(skills.begin_attack().multiplier, 1.25) and is_equal_approx(skills.begin_attack().multiplier, 1), "movement charge empowers one ordinary attack")
	setup(0, 0, 1)
	for index in 3:
		var attack := skills.begin_attack()
		skills.hit_bonus(enemy, attack.effects)
		skills.after_hit(enemy, attack.effects)
		skills.after_hit(enemy, attack.effects)
	check(skills.combo_count == 3, "multi-pellet hits count only once per attack for target combo")
	var fourth := skills.begin_attack()
	check(is_equal_approx(skills.hit_bonus(enemy, fourth.effects), 1.2), "fourth consecutive hit receives the combo bonus")
	skills.after_hit(enemy, fourth.effects)
	check(is_equal_approx(skills.hit_bonus(enemy, fourth.effects), 1.2) and skills.combo_count == 0, "all pellets share the fourth attack's bonus without recharging combo")
	setup(0, 0, 2)
	player.apply_slow(1, 0.5)
	check(is_equal_approx(player.slow_factor, 0.65), "light steps reduce slow strength by thirty percent")
	setup(1, 0, 0)
	check(is_equal_approx(skills.begin_attack().critical_chance, 0.08), "cat intuition adds eight percentage points of crit")
	setup(1, 0, 1)
	enemy.health_component.current_health = 2900
	check(is_equal_approx(skills.hit_bonus(enemy, {}), 1.2), "hunter instinct increases damage below thirty percent health")
	setup(1, 0, 2)
	skills.tick(6)
	check(is_equal_approx(skills.incoming_damage(10, false), 7) and is_equal_approx(skills.incoming_damage(10, false), 10), "danger sense mitigates exactly one hit after six seconds")
	setup(2, 0, 0)
	check(is_equal_approx(skills.damage_factor(), 1.03), "bravery adds three percent for a nearby visible enemy")
	setup(2, 0, 1)
	check(is_equal_approx(skills.incoming_damage(10, true), 8) and is_equal_approx(skills.incoming_damage(10, false), 10), "tough hide reduces contact damage while preserving projectile damage")
	setup(2, 0, 2)
	player.weapon_elements[Elements.Type.FIRE] = 0.35
	for index in 3:
		check(is_equal_approx(skills.begin_attack().multiplier, 1), "bite does not amplify attacks before the fourth")
	var bite := skills.begin_attack()
	check(is_equal_approx(bite.multiplier, 1.4) and is_equal_approx(float(bite.elements[Elements.Type.FIRE]) * float(bite.multiplier), 0.35), "fourth attack adds physical damage without multiplying elemental damage")
	setup(3, 0, 0)
	player.weapon_elements[Elements.Type.WATER] = 0.4
	check(is_equal_approx(skills.begin_attack().elements[Elements.Type.WATER], 0.46), "element affinity increases weapon enchant damage by fifteen percent")
	player.weapon_elements[Elements.Type.FIRE] = 0.7
	check(skills.strongest_element() == Elements.Type.FIRE, "element bomb selects the strongest enchantment")
	setup(3, 0, 1)
	var xp := 0
	for index in 20:
		xp += skills.experience_gain(1)
	check(xp == 23, "collector keeps fractional XP so twenty one-point pickups yield twenty-three XP")
	setup(3, 0, 2)
	enemy.control_time = 1
	check(is_equal_approx(skills.hit_bonus(enemy, {}), 1.15), "ambush increases damage against controlled enemies")
	enemy.queue_free()
	await frames()

func test_guards() -> void:
	setup(0, 0, 2)
	player.energy = 9
	var point := player.position + Vector2(80, 0)
	check(not skills.cast(point) and player.energy == 9, "insufficient energy rejects cast without spending")
	player.energy = 30
	arena.phase = Arena.Phase.EXPLORATION
	check(not skills.cast(point) and player.energy == 30, "exploration cannot spend energy on skills")
	arena.phase = Arena.Phase.COMBAT
	get_tree().paused = true
	check(not skills.cast(point) and player.energy == 30, "paused game cannot cast skills")
	get_tree().paused = false
	setup(1, 1, 2)
	check(not skills.cast(point) and player.energy == 30, "marking an empty area does not waste energy")
	setup(1, 0, 2)
	arena.dungeon.seal_room(1, true)
	await frames()
	var room := arena.dungeon.room_world_rect(1, 18)
	player.position = Vector2(room.end.x - 8, room.get_center().y)
	check(skills.cast(player.position + Vector2(1000, 0)) and arena.dungeon.room_at_world(player.position) == 1 and arena.dungeon.is_floor(player.position), "blink sweep stays inside the sealed room instead of crossing walls")
	setup(3, 0, 0)
	arena.current_floor = 5
	arena.active_room = 5
	player.position = arena.dungeon.room_center(5)
	arena._spawn_boss(player.position + Vector2(60, 0), Arena.BOSS_DATA[4])
	var boss := get_tree().get_first_node_in_group("bosses") as BastionWarden
	boss.set_physics_process(false)
	var hp := boss.health_component.current_health
	var shield := boss.shield_health
	check(skills.deal(boss, 2.5, Elements.Type.FIRE) and boss.shield_health < shield and boss.health_component.current_health == hp, "pure elemental skill damages armor without bypassing Boss core shield")
	boss.state = DungeonBoss.State.REFORGE
	check(not skills.deal(boss, 100, Elements.Type.WATER) and boss.health_component.current_health == hp, "skill damage respects Boss reforge invulnerability")
	boss.state = DungeonBoss.State.CHASE
	check(skills.deal(boss, 999, Elements.Type.FIRE) and boss.phase_index == 2 and boss.state == DungeonBoss.State.REFORGE, "huge elemental skill cannot skip a Boss phase")
	boss.queue_free()
	await frames()
	setup(2, 1, 1)
	skills.cast(player.position)
	arena.phase = Arena.Phase.EXPLORATION
	skills.tick(0.1)
	check(skills.shield == 0 and skills.dash_remaining == 0, "leaving combat clears temporary effects")
	setup(0, 0, 2)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	skills._unhandled_input(event)
	check(player.energy == 20 and skills.dash_remaining > 0, "Q input really invokes and pays for the equipped active skill")

func test_selection() -> void:
	arena.hide()
	arena.hud.hide()
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	var selection := preload("res://Scene/ui/CharacterSelection/character_selection.tscn").instantiate() as CharacterSelection
	ui_layer.add_child(selection)
	await frames()
	await capture("skills-character-selection")
	for character in 4:
		Global.selected_player = PLAYERS[character]
		selection.open_skill_tree()
		await frames()
		var tree := selection.skill_tree
		check(tree.buttons.size() == 6, PLAYERS[character].id + " displays all six skill tree nodes")
		var active: String = SkillCatalog.choices(PLAYERS[character].id, "active")[2].id
		var passive: String = SkillCatalog.choices(PLAYERS[character].id, "passive")[1].id
		tree.choose(active)
		tree.choose(passive)
		var loadout := Global.get_skill_loadout(PLAYERS[character].id)
		check(loadout.active == active and loadout.passive == passive, "cross-branch active/passive choices are saved independently")
		await capture("skill-tree-" + PLAYERS[character].id.to_lower())
		for attempt in 15:
			tree.randomize_loadout()
			loadout = Global.get_skill_loadout(PLAYERS[character].id)
			check(SkillCatalog.valid(loadout.active, PLAYERS[character].id, "active") and SkillCatalog.valid(loadout.passive, PLAYERS[character].id, "passive"), "random loadout stays within the chosen character's two pools")
	selection.queue_free()
	ui_layer.queue_free()
	await frames()
	arena.show()
	arena.hud.show()
	setup(0, 0, 2)
	player.energy = 20
	player.energy_changed.emit(20, 30)
	arena.hud.toast_time = 0
	player.get_node("Camera2D").reset_smoothing()
	await capture("skills-battle-hud")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			folder = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
	Global.selected_player = PLAYERS[0]
	Global.selected_weapon = preload("res://Data/Weapons/weapon_sword.tres")
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 1015
	add_child(arena)
	arena.set_physics_process(false)
	player = arena.player
	player.set_physics_process(false)
	player.weapon_controller.set_physics_process(false)
	skills = player.skills
	skills.set_physics_process(false)
	test_catalog()
	await test_actives()
	await test_passives()
	await test_guards()
	await test_selection()
	print("RESULT: %d/%d skill system checks passed" % [checks - failures, checks])
	arena.queue_free()
	await frames()
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
