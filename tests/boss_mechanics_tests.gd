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

func make_boss(floor_number: int) -> DungeonBoss:
	arena.current_floor = floor_number
	arena.phase = Arena.Phase.COMBAT
	arena.active_room = 5
	arena.player.global_position = arena.dungeon.room_center(5) + Vector2(-100, 50)
	arena.player.invulnerability = 999
	arena._spawn_boss(arena.dungeon.room_center(5) + Vector2(60, 0), Arena.BOSS_DATA[floor_number - 1])
	var boss := get_tree().get_first_node_in_group("bosses") as DungeonBoss
	boss.set_physics_process(false)
	return boss

func projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemy_attacks").filter(func(node: Node) -> bool: return node is EnemyProjectile)

func freeze_attacks() -> void:
	for attack in get_tree().get_nodes_in_group("enemy_attacks"):
		attack.set_physics_process(false)
		attack.set_process(false)

func clear_attacks() -> void:
	for attack in get_tree().get_nodes_in_group("enemy_attacks"):
		attack.queue_free()
	await frames()

func cleanup() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await clear_attacks()
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	await frames()

func run() -> void:
	arena = preload("res://Scene/Arena/arena.tscn").instantiate() as Arena
	arena.map_seed = 4481
	add_child(arena)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.player.weapon_controller.set_physics_process(false)
	arena.player.health_component.init_health(1000)
	arena.dungeon.seal_room(5, true)
	await frames()
	await test_normal_health()
	await test_roster()
	await test_tree()
	await test_tree_freed_minions()
	await test_mage()
	await test_assassin()
	await test_warden()
	await test_warden_open_combat()
	await test_warden_phases()
	await test_projectile_collision()
	print("RESULT: %d/%d boss checks passed" % [checks - failures, checks])
	arena.queue_free()
	await frames()
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)

func test_normal_health() -> void:
	for kind in 3:
		check(is_equal_approx(Arena.ENEMIES[kind].max_health, [3.0, 2.2, 10.0][kind] * 1.5), "normal enemy %d base health increases exactly fifty percent" % kind)
	for floor_number in range(1, 6):
		arena.current_floor = floor_number
		for kind in 3:
			arena._spawn_enemy(arena.dungeon.room_center(1), Arena.ENEMIES[kind], 1)
			var enemy := get_tree().get_nodes_in_group("enemies").back() as Enemy
			enemy.set_physics_process(false)
			check(is_equal_approx(enemy.health_component.max_health, [3.0, 2.2, 10.0][kind] * 1.5 * (1.0 + (floor_number - 1) * 0.45)), "floor %d enemy %d keeps its floor scaling on top of the fifty percent increase" % [floor_number, kind])
	await cleanup()

func test_roster() -> void:
	var classes: Array[Script] = []
	for floor_number in range(1, 6):
		var boss := make_boss(floor_number)
		classes.append(boss.get_script())
		check(boss.data == Arena.BOSS_DATA[floor_number - 1] and boss.element == floor_number, "floor %d loads designated boss and element" % floor_number)
		check(is_equal_approx(boss.health_component.max_health, 90.0 * pow(2, floor_number - 1)), "floor %d boss health doubles from the previous floor without normal-enemy scaling" % floor_number)
		check(is_equal_approx(boss.skill_time, 1.25) and is_equal_approx(boss.skill_duration(boss.normal_skill_interval), boss.normal_skill_interval * 0.5), "floor %d boss initial and repeated skill cooldowns are halved" % floor_number)
		var animations_ok := true
		for animation in ["idle", "walk", "attack", "death"]:
			animations_ok = animations_ok and boss.boss_sprite.sprite_frames.has_animation(animation) and boss.boss_sprite.sprite_frames.get_frame_count(animation) == 4
		check(animations_ok and not boss.boss_sprite.sprite_frames.get_animation_loop("death"), "floor %d has four four-frame animations and finite death" % floor_number)
		arena.hud._process(0)
		check(arena.hud.boss_label.text.contains(boss.data.enemy_name), "floor %d HUD identifies actual boss" % floor_number)
		boss._start_slam()
		var expected_cast: float = [0.425, 0.45, 0.375, 0.325, 0.45][floor_number - 1]
		check(is_equal_approx(boss.state_time, expected_cast), "floor %d skill windup is halved" % floor_number)
		var warnings_match := true
		for attack in get_tree().get_nodes_in_group("enemy_attacks"):
			if attack is GroundHazard:
				warnings_match = warnings_match and is_equal_approx(attack.warning_time, expected_cast)
			elif attack is BossTelegraph:
				warnings_match = warnings_match and is_equal_approx(attack.duration, expected_cast)
		check(warnings_match, "floor %d visual warning matches the faster cast timing" % floor_number)
		await cleanup()
	check(classes.size() == 5 and classes[1] != classes[2] and classes[2] != classes[3] and classes[3] != classes[4], "five-floor roster uses distinct boss behaviors")

func test_tree() -> void:
	var boss := make_boss(2) as ThornSovereign
	boss._start_slam()
	check(boss.state == DungeonBoss.State.CAST and get_tree().get_nodes_in_group("boss_minions").is_empty(), "tree summon has windup before servants appear")
	boss._tick_special_state(0.91)
	check(get_tree().get_nodes_in_group("spawn_markers").size() == 2, "normal tree schedules two telegraphed summons")
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	await frames(5)
	for minion: Enemy in boss.owned_minions:
		minion.set_physics_process(false)
	check(boss.owned_minions.size() == 2, "tree summon produces two servants")
	check(boss.owned_minions.all(func(minion: Enemy) -> bool: return is_equal_approx(minion.health_component.max_health, 3.0 * 1.5 * 1.24)), "summoned servants also receive exactly fifty percent more health")
	check(boss.owned_minions.all(func(minion: Enemy) -> bool: return minion.data.experience == 0 and minion.data.coins == 0 and minion.element == Elements.Type.WOOD), "servants have wood affinity and cannot farm experience or coins")
	boss.enraged = true
	for repetition in 4:
		boss._summon_servants()
	for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
		marker.remaining = 0.001
	await frames(5)
	for minion: Enemy in boss.owned_minions:
		minion.set_physics_process(false)
	check(boss.owned_minions.size() == 4, "repeated enraged summons never exceed four living servants")
	await clear_attacks()
	boss.skill_index = 1
	boss._start_slam()
	freeze_attacks()
	var roots := get_tree().get_nodes_in_group("enemy_attacks").filter(func(node: Node) -> bool: return node is GroundHazard)
	check(roots.size() == 3, "tree root attack places three lingering circles")
	var root := roots[1] as GroundHazard
	arena.player.global_position = root.global_position
	arena.player.slow_time = 0
	root._physics_process(0.24)
	check(arena.player.slow_time == 0, "root warning cannot slow or damage player")
	root._physics_process(0.27)
	check(is_equal_approx(arena.player.slow_factor, 0.65) and arena.player.slow_time > 0, "standing in active roots applies 35 percent slow")
	check(root.active_duration == 3.6 and root.tick_interval > 0, "roots have a bounded duration and damage tick interval")
	arena.player.can_move = false
	arena.player._physics_process(0.81)
	arena.player.can_move = true
	check(arena.player.slow_time == 0, "root slow expires after leaving the hazard")
	await clear_attacks()
	boss.skill_index = 2
	boss._start_slam()
	boss._tick_special_state(0.91)
	freeze_attacks()
	check(projectiles().size() == 13, "enraged tree combines seven seed shots and six radial shots")
	await clear_attacks()
	boss.owned_minions[0].take_hit(9999)
	await frames()
	check(get_tree().get_nodes_in_group("pickups").is_empty(), "killing summoned servants drops no resources or healing")
	boss._summon_servants()
	boss.take_hit(9999)
	await frames()
	check(get_tree().get_nodes_in_group("enemies").is_empty() and get_tree().get_nodes_in_group("spawn_markers").is_empty(), "tree death clears living servants and pending summons immediately")
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "tree death clears its remaining hazards")
	await cleanup()

func test_tree_freed_minions() -> void:
	# The death tween frees servants after 0.16 seconds; retaining those
	# references is different from testing only dead, still-valid nodes.
	arena.hud.set_process(false)
	for cleanup_entry in ["summon", "spawn", "hud"]:
		var boss := make_boss(2) as ThornSovereign
		for index in 3:
			boss._spawn_servant(boss.position + Vector2(0, (index - 1) * 60), ThornSovereign.MINION_DATA)
			boss.owned_minions[index].set_physics_process(false)
		var dying := boss.owned_minions[0]
		var removed := boss.owned_minions[1]
		dying.take_hit(9999)
		removed.queue_free()
		await get_tree().create_timer(0.25).timeout
		check(not is_instance_valid(dying) and not is_instance_valid(removed), cleanup_entry + " regression includes two actually freed servants")
		match cleanup_entry:
			"summon":
				boss.enraged = true
				boss.skill_index = 3
				boss._start_slam()
				boss._tick_special_state(0.91)
				check(boss.owned_minions.size() == 1 and get_tree().get_nodes_in_group("spawn_markers").size() == 3, "second enraged summon prunes freed servants and schedules three replacements")
				for marker: SpawnMarker in get_tree().get_nodes_in_group("spawn_markers"):
					marker.remaining = 0.001
				await frames(5)
				check(boss.owned_minions.size() == 4 and boss.owned_minions.is_typed(), "replacement summons preserve typed array and four-servant limit")
			"spawn":
				boss._spawn_servant(boss.position + Vector2(0, 80), ThornSovereign.MINION_DATA)
				check(boss.owned_minions.size() == 2 and boss.owned_minions.is_typed(), "delayed spawn safely prunes freed servants and retains array type")
			"hud":
				check(boss.status_text().contains("1/4"), "HUD counts only living servants after freed references remain")
				check(boss.owned_minions.size() == 1 and boss.owned_minions.is_typed(), "HUD cleanup retains Enemy array type")
		await cleanup()
	arena.hud.set_process(true)

func release_mage(boss: TideArchmage, skill: int) -> void:
	boss.skill_index = skill
	boss._start_slam()
	boss._tick_special_state(0.76)
	boss._tick_special_state(0.01)
	freeze_attacks()

func test_mage() -> void:
	var boss := make_boss(3) as TideArchmage
	boss._start_slam()
	check(projectiles().is_empty() and boss.state_time > 0, "mage warns before firing its first volley")
	boss._tick_special_state(0.76)
	boss._tick_special_state(0.01)
	freeze_attacks()
	check(projectiles().size() == 7, "mage opens with seven spread shots")
	boss._tick_special_state(0.33)
	boss._tick_special_state(0.33)
	freeze_attacks()
	check(projectiles().size() == 21 and boss.state == DungeonBoss.State.RECOVER, "mage fires exactly three volleys then recovers")
	await clear_attacks()
	await release_mage(boss, 1)
	boss._tick_special_state(0.33)
	boss._tick_special_state(0.33)
	freeze_attacks()
	check(projectiles().size() == 36 and projectiles().all(func(node: EnemyProjectile) -> bool: return absf(node.curve_rate) > 0), "mage spiral releases three curved twelve-shot rings")
	await clear_attacks()
	await release_mage(boss, 2)
	check(projectiles().size() == 3 and projectiles().all(func(node: EnemyProjectile) -> bool: return node.homing_turn_rate > 0 and node.lifetime <= 4), "mage homing orbs are limited in number and lifetime")
	var orb := projectiles()[0] as EnemyProjectile
	orb.position = arena.player.position + Vector2(-60, -45)
	orb.direction = Vector2.RIGHT
	var old_direction := orb.direction
	orb._physics_process(0.1)
	check(not orb.direction.is_equal_approx(old_direction) and absf(old_direction.angle_to(orb.direction)) <= 0.151, "homing orbs turn toward player at a capped angular speed")
	orb.age = orb.homing_duration
	var released_direction := orb.direction
	arena.player.position += Vector2(0, 30)
	orb._physics_process(0.01)
	check(orb.direction.is_equal_approx(released_direction), "homing ends after its short pursuit window")
	orb._physics_process(5)
	await frames()
	check(not is_instance_valid(orb), "homing orbs expire")
	await clear_attacks()
	boss.enraged = true
	await release_mage(boss, 0)
	check(projectiles().size() == 9 and boss.volleys_left == 3, "enraged mage upgrades to four nine-shot volleys")
	boss.take_hit(9999)
	await frames()
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "mage death clears all owned bullets and warnings")
	await cleanup()

func test_assassin() -> void:
	var boss := make_boss(4) as EmberStalker
	boss._start_slam()
	var hp := boss.health_component.current_health
	check(boss.state == DungeonBoss.State.BLINK and boss.collision_layer == 0 and boss.visuals.modulate.a < 0.2, "assassin blink visibly fades and disables hit collision")
	check(not boss.take_hit(10) and boss.health_component.current_health == hp, "assassin cannot be damaged during actual blink")
	check(boss.room_bounds.has_point(boss.blink_destination) and arena.dungeon.is_floor(boss.blink_destination) and boss.blink_destination.distance_to(arena.player.position) >= 100, "blink destination is on floor inside room with player separation")
	check(get_tree().get_nodes_in_group("enemy_attacks").size() == 2, "blink warns landing circle and dash line")
	var locked := boss.dash_direction
	boss._tick_special_state(0.66)
	check(boss.state == DungeonBoss.State.DASH and boss.collision_layer == 4 and boss.visuals.modulate.a == 1, "assassin restores opacity and damage collision before dashing")
	arena.player.position = boss.position + locked * 65
	arena.player.invulnerability = 0
	var player_hp := arena.player.health_component.current_health
	for tick in 24:
		await get_tree().physics_frame
		arena.player.invulnerability = 0
		boss._physics_process(1.0 / 60)
	check(boss.dash_direction.is_equal_approx(locked), "dash direction stays locked after player moves")
	check(is_equal_approx(player_hp - arena.player.health_component.current_health, boss.data.contact_damage * boss.damage_scale), "swept dash hits once even without player immunity")
	check(boss.state == DungeonBoss.State.RECOVER and boss.room_bounds.has_point(boss.position), "dash ends with recovery and stays inside sealed room")
	arena.player.invulnerability = 999
	boss.skill_index = 1
	boss.enraged = true
	boss._start_slam()
	check(boss.dashes_left == 3 and not boss.teleporting and boss.collision_layer == 4, "enraged chain attack has three dashes with vulnerable windups")
	hp = boss.health_component.current_health
	check(boss.take_hit(1) and boss.health_component.current_health < hp, "chain-dash warning can be punished with attacks")
	boss._tick_special_state(0.66)
	boss._tick_special_state(0.37)
	check(boss.state == DungeonBoss.State.BLINK and is_equal_approx(boss.state_time, 0.225) and boss.dashes_left == 2, "chain dash inserts a halved warning interval between strikes")
	await clear_attacks()
	boss.skill_index = 2
	boss._start_slam()
	freeze_attacks()
	check(get_tree().get_nodes_in_group("enemy_attacks").size() == 3 and get_tree().get_nodes_in_group("enemy_attacks").all(func(node: GroundHazard) -> bool: return node.active_duration == 1.7), "assassin third skill leaves three timed fire zones")
	boss.take_hit(9999)
	await frames()
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "assassin death clears fire zones")
	await cleanup()

func test_warden() -> void:
	var boss := make_boss(5) as BastionWarden
	check(boss.state == DungeonBoss.State.SHIELDED and is_equal_approx(boss.shield_health, 504), "final boss begins with a 35 percent shield on 1440 health")
	arena.hud._process(0)
	check(arena.hud.boss_shield_bar.visible and arena.hud.boss_status_label.text.contains("本体免伤"), "HUD exposes shield health and immunity hint")
	var hp := boss.health_component.current_health
	var shield := boss.shield_health
	boss.take_hit(2, Vector2.ZERO, 0, false, {Elements.Type.WOOD: 0.35})
	check(boss.health_component.current_health == hp and is_equal_approx(shield - boss.shield_health, 3.05 * 0.75), "shield reduces the complete physical and counter-element hit by twenty-five percent while core stays immune")
	boss._tick_special_state(1.6)
	check(get_tree().get_nodes_in_group("enemy_attacks").size() == 2 and projectiles().is_empty(), "shielded boss warns pulse and ranged attacks before shooting")
	boss.take_hit(9999)
	check(boss.state == DungeonBoss.State.VULNERABLE and boss.health_component.current_health == hp and boss.shield_health == 0, "breaking shield opens vulnerability without overflow damage")
	await frames()
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "shield break cancels pending pulse attacks")
	arena.hud._process(0)
	check(not arena.hud.boss_shield_bar.visible and arena.hud.boss_status_label.text.contains("破盾虚弱"), "HUD clearly shows vulnerability window")
	boss.take_hit(2, Vector2.ZERO, 0, false, {Elements.Type.WOOD: 0.35})
	check(is_equal_approx(hp - boss.health_component.current_health, 3.05 * 1.25), "short vulnerability amplifies full physical and elemental hit by 1.25")
	boss._tick_special_state(0.99)
	check(boss.state == DungeonBoss.State.VULNERABLE, "shield break provides one full second of stagger")
	boss._tick_special_state(0.02)
	check(boss.state == DungeonBoss.State.CHASE and boss.skill_time <= 0.12, "after one second the boss resumes pursuit and prepares an immediate counterattack")
	hp = boss.health_component.current_health
	boss.take_hit(2)
	check(is_equal_approx(hp - boss.health_component.current_health, 2), "damage returns to normal after vulnerability")
	boss.skill_index = 1
	boss._start_slam()
	boss._tick_special_state(0.91)
	freeze_attacks()
	check(projectiles().size() == 5 and boss.state == DungeonBoss.State.CAST, "warden rock fan starts a two-wave attack")
	boss._tick_special_state(0.19)
	freeze_attacks()
	check(projectiles().size() == 10 and boss.state == DungeonBoss.State.RECOVER, "warden second fan wave releases before recovery")
	await clear_attacks()
	boss._start_slam()
	freeze_attacks()
	check(get_tree().get_nodes_in_group("enemy_attacks").filter(func(node: Node) -> bool: return node is GroundHazard).size() == 3, "warden quake places three staggered impact zones")
	await clear_attacks()
	boss._start_slam()
	check(boss.state == DungeonBoss.State.CAST and boss.shield_health == 0, "skill cycles keep fighting without prematurely ending the exposed damage window")
	await clear_attacks()
	hp = boss.health_component.current_health
	boss.exposed_time = 0.01
	boss._physics_process(0.02)
	check(boss.state == DungeonBoss.State.REFORGE and not boss.reforge_full and boss.phase_index == 1, "expired exposure triggers a telegraphed same-phase partial repair")
	check(not boss.take_hit(9999) and boss.health_component.current_health == hp, "partial repair windup respects temporary immunity without healing core health")
	boss._tick_special_state(0.91)
	check(boss.state == DungeonBoss.State.SHIELDED and is_equal_approx(boss.shield_health, 302.4) and boss.health_component.current_health == hp, "same-phase repair restores only sixty percent of the current shield capacity")
	boss.take_hit(9999)
	boss.take_hit(9999)
	check(not boss.health_component.is_dead and boss.state == DungeonBoss.State.REFORGE, "two huge hits trigger a phase transition instead of skipping the final fight")
	for stage in 2:
		boss._tick_special_state(0.91)
		boss.take_hit(9999)
		boss.take_hit(9999)
	await frames()
	check(boss.health_component.is_dead and get_tree().get_nodes_in_group("bosses").is_empty(), "warden can be killed through normal break-then-damage sequence")
	await cleanup()

func test_warden_open_combat() -> void:
	var boss := make_boss(5) as BastionWarden
	boss.take_hit(10)
	var shield := boss.shield_health
	boss.pulse_timer = 999
	for tick in 20:
		await get_tree().physics_frame
		boss._physics_process(1.0 / 60)
	check(is_equal_approx(boss.shield_health, shield), "active armor never regenerates while the player is trying to break it")
	boss.take_hit(99999)
	var origin := boss.position
	boss._physics_process(0.99)
	check(boss.state == DungeonBoss.State.VULNERABLE and boss.position.is_equal_approx(origin), "only the deliberate one-second stagger holds the broken boss still")
	boss._physics_process(0.02)
	check(boss.state == DungeonBoss.State.CHASE and is_equal_approx(boss.exposed_time, 6.99), "core stays exposed after the brief stagger instead of immediately regaining armor")
	for tick in 60:
		await get_tree().physics_frame
		boss._physics_process(1.0 / 60)
		freeze_attacks()
	check(boss.position.distance_to(origin) > 10 and boss.shield_health == 0, "broken boss moves while remaining damageable")
	check(projectiles().size() >= 5, "broken boss counterattacks within one second instead of becoming a stationary target")
	var hp := boss.health_component.current_health
	boss.take_hit(2)
	check(is_equal_approx(hp - boss.health_component.current_health, 2), "moving and casting after the stagger keeps the core vulnerable to normal damage")
	await clear_attacks()
	boss.skill_index = 1
	boss._start_slam()
	origin = boss.position
	for tick in 12:
		await get_tree().physics_frame
		boss._physics_process(1.0 / 60)
	check(boss.state == DungeonBoss.State.CAST and boss.position.distance_to(origin) > 3, "rock-fan windup actively strafes while preserving its warning")
	var remaining := boss.exposed_time
	boss.set_physics_process(true)
	get_tree().paused = true
	await get_tree().create_timer(0.05).timeout
	check(boss.exposed_time == remaining, "pause freezes the exposed-core repair timer")
	boss.set_physics_process(false)
	get_tree().paused = false
	await clear_attacks()
	boss.apply_slow(5, 0.5)
	boss.apply_burn(1)
	boss.exposed_time = 0.01
	hp = boss.health_component.current_health
	boss._physics_process(0.02)
	check(boss.state == DungeonBoss.State.REFORGE and boss.slow_time == 0 and boss.burn_time == 0, "timed repair clears active statuses and starts an explicit warning")
	check(boss.status_text().contains("六成") and boss.health_component.current_health == hp, "repair UI explains the partial restoration and preserves core wounds")
	await cleanup()

func test_warden_phases() -> void:
	var boss := make_boss(5) as BastionWarden
	var origin := boss.global_position
	var distance := origin.distance_to(arena.player.global_position)
	boss.pulse_timer = 999
	for tick in 60:
		await get_tree().physics_frame
		boss._physics_process(1.0 / 60)
	check(boss.state == DungeonBoss.State.SHIELDED and boss.global_position.distance_to(origin) > 25, "shielded warden actively moves rather than staying stationary")
	check(boss.global_position.distance_to(arena.player.global_position) < distance and boss.room_bounds.has_point(boss.position), "shielded pursuit approaches the player and stays in the sealed room")
	check(boss.boss_sprite.animation == &"walk", "shielded pursuit plays the walking animation")
	boss.pulse_timer = 0
	boss._tick_special_state(0.01)
	freeze_attacks()
	check(projectiles().is_empty() and boss.shield_volley_timer > 0, "shielded ranged attack has a real warning delay")
	var aim := boss.shield_aim
	arena.player.position += Vector2(0, 60)
	boss._tick_special_state(0.43)
	freeze_attacks()
	check(projectiles().size() == 3 and boss.shield_aim.is_equal_approx(aim), "first-stage shield fan fires toward the locked warning target")
	await clear_attacks()
	boss.take_hit(99999, Vector2.ZERO, 0, true, {Elements.Type.WOOD: 2.0})
	check(boss.health_component.current_health == boss.health_component.max_health, "overkill against the shield never spills into core health")
	var threshold := boss.health_component.max_health * 2.0 / 3.0
	boss.take_hit(99999, Vector2.ZERO, 0, true, {Elements.Type.WOOD: 2.0, Elements.Type.FIRE: 2.0})
	check(boss.phase_index == 2 and boss.state == DungeonBoss.State.REFORGE and is_equal_approx(boss.health_component.current_health, threshold), "critical elemental overkill stops at the two-thirds phase boundary")
	for pellet in 50:
		boss.take_hit(99999)
	check(is_equal_approx(boss.health_component.current_health, threshold) and not boss.health_component.is_dead, "same-frame volleys cannot bypass the reforge phase")
	check(not boss.can_receive_status_effects(), "reforge rejects frost and burn status effects")
	boss.apply_slow(5, 0.5)
	boss.apply_burn(99999)
	check(boss.slow_time == 0 and boss.burn_time == 0, "reforge immunity also rejects direct status application")
	check(boss.status_text().contains("阶段 2/3") and boss.status_text().contains("重铸"), "HUD explains the phase transition and temporary immunity")
	boss._tick_special_state(0.89)
	check(boss.state == DungeonBoss.State.REFORGE, "reforge remains visible for its 0.9 second duration")
	boss._tick_special_state(0.02)
	check(boss.state == DungeonBoss.State.SHIELDED and boss.shield_health == boss.shield_capacity, "reforge completes with full armor and active pursuit")
	check(is_equal_approx(boss.shield_capacity, 576), "second stage upgrades full shield capacity to forty percent of maximum health")
	await clear_attacks()
	boss.pulse_timer = 0
	boss._tick_special_state(0.01)
	boss._tick_special_state(0.43)
	freeze_attacks()
	check(projectiles().size() == 5, "later-phase shield fan increases from three to five projectiles")
	await clear_attacks()
	boss.take_hit(99999)
	check(boss.state == DungeonBoss.State.VULNERABLE and boss.can_receive_status_effects(), "breaking the reforged shield restores the damage opportunity")
	boss.skill_index = 2
	boss._start_slam()
	freeze_attacks()
	var zones := get_tree().get_nodes_in_group("enemy_attacks").filter(func(node: Node) -> bool: return node is GroundHazard)
	check(zones.size() == 5, "later-phase quake adds two cross impacts to its three original strikes")
	check(zones.all(func(zone: GroundHazard) -> bool: return zone.warning_time >= 0.45 and zone.radius <= 36), "cross impacts retain warning time and leave room to dodge")
	await clear_attacks()
	boss.enraged = true
	boss.skill_index = 1
	boss._start_slam()
	boss._tick_special_state(0.46)
	boss._tick_special_state(0.19)
	boss._tick_special_state(0.19)
	freeze_attacks()
	check(projectiles().size() == 21 and boss.state == DungeonBoss.State.RECOVER, "enraged warden fires three seven-shot waves and then recovers")
	await clear_attacks()
	boss.health_component.current_health = boss.health_component.max_health / 3.0 + 1
	boss.apply_burn(99999)
	boss._tick_status_effects(0.5)
	check(boss.phase_index == 3 and boss.state == DungeonBoss.State.REFORGE and is_equal_approx(boss.health_component.current_health, boss.health_component.max_health / 3.0), "lethal burn also stops at the one-third phase boundary")
	check(boss.burn_time == 0 and boss.burn_tick_damage == 0, "phase transition clears burning damage before reforging armor")
	boss._tick_special_state(0.91)
	check(is_equal_approx(boss.shield_capacity, 648), "third stage upgrades full shield capacity to forty-five percent of maximum health")
	boss.take_hit(99999)
	var kills := arena.kills
	boss.take_hit(99999)
	check(boss.health_component.is_dead and arena.kills == kills + 1, "third-phase core can be defeated and emits one normal boss reward")
	check(not boss.take_hit(99999) and arena.kills == kills + 1, "dead final boss cannot emit duplicate rewards")
	await frames()
	check(get_tree().get_nodes_in_group("enemy_attacks").is_empty(), "third-phase death clears every owned attack")
	await cleanup()

func test_projectile_collision() -> void:
	var boss := make_boss(3)
	var rect := arena.dungeon.room_world_rect(5, 40)
	boss.position = rect.position + Vector2(60, rect.size.y / 2)
	var shot := boss._shoot(Vector2.LEFT, 500)
	shot.set_physics_process(false)
	await frames()
	shot._physics_process(1)
	await frames()
	check(not is_instance_valid(shot), "fast boss projectile ray sweep stops at dungeon walls")
	boss.position = arena.dungeon.room_center(5)
	arena.player.position = boss.position + Vector2(80, -7)
	arena.player.invulnerability = 0
	var hp := arena.player.health_component.current_health
	shot = boss._shoot(Vector2.RIGHT, 500)
	shot.set_physics_process(false)
	await frames()
	shot._physics_process(0.2)
	await frames()
	check(not is_instance_valid(shot) and arena.player.health_component.current_health < hp, "fast boss projectile swept collision damages player and disappears")
	await cleanup()
