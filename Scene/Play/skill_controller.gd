extends Node2D
class_name SkillController

const EFFECT = preload("res://Scene/Effects/skill_effect.gd")
var player: Player
var active_id: String = ""
var passive_id: String = ""
var cooldown: float = 0
var haste_time: float = 0
var speed_time: float = 0
var power_time: float = 0
var critical_time: float = 0
var shield_time: float = 0
var shield: float = 0
var no_hit_time: float = 0
var movement_charge: float = 0
var charge_ready := false
var last_position := Vector2.ZERO
var attack_serial: int = 0
var combo_target: int = 0
var combo_count: int = 0
var marked_target: WeakRef
var mark_time: float = 0
var experience_remainder: float = 0
var was_combat := false
var dash_remaining: float = 0
var dash_direction := Vector2.RIGHT
var dash_factor: float = 0
var dash_hits: Dictionary[int, bool] = {}
var cast_token: Dictionary = {}

func configure(active: String, passive: String) -> void:
	clear_transient()
	active_id = active if SkillCatalog.valid(active, player.data.id, "active") else ""
	passive_id = passive if SkillCatalog.valid(passive, player.data.id, "passive") else ""
	cooldown = 0
	no_hit_time = 0
	movement_charge = 0
	charge_ready = false
	attack_serial = 0
	experience_remainder = 0
	last_position = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("active_skill") and not event.is_echo():
		cast(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func in_combat() -> bool:
	return is_instance_valid(player.arena) and player.arena.phase == Arena.Phase.COMBAT and not player.health_component.is_dead and player.can_move and not get_tree().paused

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if get_tree().paused:
		return
	var combat := in_combat()
	if was_combat and not combat:
		clear_transient()
	was_combat = combat
	player.item_effects.tick(delta)
	cooldown = maxf(0, cooldown - delta)
	haste_time = maxf(0, haste_time - delta)
	speed_time = maxf(0, speed_time - delta)
	power_time = maxf(0, power_time - delta)
	critical_time = maxf(0, critical_time - delta)
	shield_time = maxf(0, shield_time - delta)
	mark_time = maxf(0, mark_time - delta)
	if shield_time <= 0:
		shield = 0
	if combat:
		no_hit_time = minf(6, no_hit_time + delta)
		if passive_id == "bunny_charge" and not charge_ready and dash_remaining <= 0:
			# Ignore teleports, floor transitions and other discontinuous moves.
			movement_charge += minf(player.global_position.distance_to(last_position), player.data.move_speed * player.speed_multiplier * 1.3 * delta + 1)
			if movement_charge >= 160:
				charge_ready = true
				movement_charge = 0
	last_position = player.global_position
	if dash_remaining > 0 and combat:
		var start := player.global_position
		var distance := minf(dash_remaining, 650 * delta)
		for step in ceili(distance / 5):
			var motion := dash_direction * minf(5, distance - step * 5)
			if player.test_move(player.global_transform, motion):
				dash_remaining = 0
				break
			player.global_position += motion
		dash_remaining = maxf(0, dash_remaining - distance)
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy.health_component.is_dead and Geometry2D.get_closest_point_to_segment(enemy.global_position, start, player.global_position).distance_to(enemy.global_position) <= 19 + enemy.data.size_scale * 5 and clear_ray(player.global_position, enemy.global_position) and not dash_hits.has(enemy.get_instance_id()):
				dash_hits[enemy.get_instance_id()] = true
				if deal(enemy, dash_factor) and active_id == "dog_charge":
					enemy.apply_control(0.8, false, player.global_position)
		player.velocity = Vector2.ZERO
		player.knockback_velocity = Vector2.ZERO
		player.item_effects.record_movement(start, player.global_position)
	queue_redraw()

func clear_transient() -> void:
	player.item_effects.clear_transient()
	cast_token = {}
	haste_time = 0
	speed_time = 0
	power_time = 0
	critical_time = 0
	shield_time = 0
	shield = 0
	mark_time = 0
	marked_target = null
	dash_remaining = 0
	dash_hits.clear()
	combo_target = 0
	combo_count = 0
	if is_inside_tree():
		for effect in get_tree().get_nodes_in_group("player_skill_effects"):
			if effect.caster == player:
				effect.queue_free()

func cast(mouse_point: Vector2) -> bool:
	if active_id.is_empty() or not in_combat():
		return false
	var definition := SkillCatalog.find(active_id)
	if cooldown > 0 or dash_remaining > 0:
		_notify("技能冷却中")
		return false
	if player.energy < int(definition.cost):
		_notify("能量不足 · 需要 %d 格" % (int(definition.cost) / Player.ENERGY_PER_CELL))
		return false
	var aim := player.global_position.direction_to(mouse_point)
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var point := aim_point(mouse_point, 180)
	var selected: Enemy
	if active_id == "cat_mark":
		var best := 80.0
		for enemy in enemies_at(point, 80):
			var distance := enemy.global_position.distance_to(point)
			if distance < best and enemy.can_receive_status_effects():
				selected = enemy
				best = distance
		if not is_instance_valid(selected):
			_notify("鼠标附近没有可标记的敌人")
			return false
	if not player.consume_energy(int(definition.cost)):
		return false
	cast_token = {"refunded": false}
	player.item_effects.on_cast()
	cooldown = float(definition.cooldown)
	match active_id:
		"bunny_dash", "dog_charge":
			dash_direction = aim
			dash_remaining = 105 if active_id == "bunny_dash" else 145
			dash_factor = 0.8 if active_id == "bunny_dash" else 2.2
			dash_hits.clear()
			player.invulnerability = maxf(player.invulnerability, 0.22 if active_id == "bunny_dash" else 0.26)
			if active_id == "bunny_dash":
				haste_time = 2
		"bunny_blade":
			var effect = spawn_effect("blade", player.global_position, 1.0)
			effect.direction = aim
			effect.factor = 1.0
		"bunny_decoy":
			spawn_effect("decoy", player.global_position, 2)
			speed_time = 3
		"cat_blink":
			# A swept body prevents blinking through walls or sealed doors.
			var blink_start := player.global_position
			for index in 24:
				var motion := aim * 5
				if player.test_move(player.global_transform, motion):
					break
				player.global_position += motion
			player.item_effects.record_movement(blink_start, player.global_position)
			player.knockback_velocity = Vector2.ZERO
			player.invulnerability = maxf(player.invulnerability, 0.25)
			critical_time = 3
			spawn_effect("flash", player.global_position, 0.4)
		"cat_mark":
			marked_target = weakref(selected)
			mark_time = 5
			var effect = spawn_effect("mark", selected.global_position, 5)
			effect.follow = weakref(selected)
		"cat_smoke":
			spawn_effect("smoke", point, 3)
		"dog_roar":
			for enemy in enemies_at(player.global_position, 90):
				if deal(enemy, 1.5):
					enemy.apply_control(1, true, player.global_position)
			power_time = 3
			spawn_effect("flash", player.global_position, 0.5).radius = 90
		"dog_shield":
			shield = player.health_component.max_health * 0.35
			shield_time = 4
		"mouse_bomb":
			var effect = spawn_effect("bomb", point, 0.8)
			effect.factor = 2.5
			effect.element = strongest_element()
		"mouse_vortex":
			spawn_effect("vortex", point, 2).factor = 0.8
		"mouse_mines":
			for index in 3:
				var offset := Vector2.RIGHT.rotated(TAU * index / 3.0) * 23
				var effect = spawn_effect("mine", aim_point(point + offset, 180), 6)
				effect.factor = 1.0
	_notify(definition.name)
	return true

func _notify(message: String) -> void:
	if is_instance_valid(player.arena) and is_instance_valid(player.arena.hud):
		player.arena.hud.toast(message)

func aim_point(point: Vector2, reach: float) -> Vector2:
	var start := player.global_position
	var end := start + (point - start).limit_length(reach)
	var ray := PhysicsRayQueryParameters2D.create(start, end, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		end = hit.position - start.direction_to(end) * 9
	return end

func clear_ray(start: Vector2, end: Vector2) -> bool:
	return get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, end, 1)).is_empty()

func enemies_at(point: Vector2, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.health_component.is_dead and enemy.global_position.distance_to(point) <= radius + enemy.data.size_scale * 5 and clear_ray(point, enemy.global_position):
			result.append(enemy)
	return result

func spawn_effect(kind: String, point: Vector2, duration: float):
	var effect = EFFECT.new()
	effect.caster = player
	effect.cast_token = cast_token
	effect.kind = kind
	effect.lifetime = duration
	effect.position = point
	player.arena.actors.add_child(effect)
	return effect

func strongest_element() -> int:
	var result := Elements.Type.EARTH
	var strongest := 0.0
	for element: int in player.weapon_elements:
		if player.weapon_elements[element] > strongest:
			strongest = player.weapon_elements[element]
			result = element
	return result

func damage_factor() -> float:
	var result := 1.2 if power_time > 0 else 1.0
	if passive_id == "dog_bravery":
		result *= 1.0 + mini(5, enemies_at(player.global_position, 100).size()) * 0.03 * player.item_effects.passive_scale()
	return result

func speed_factor() -> float:
	return (1.3 if speed_time > 0 else 1.0) * player.item_effects.speed_factor()

func cooldown_factor() -> float:
	return (1.0 / 1.2 if haste_time > 0 else 1.0) * player.item_effects.cooldown_factor()

func begin_attack() -> Dictionary:
	attack_serial += 1
	var factor := damage_factor() * player.item_effects.begin_attack()
	if passive_id == "bunny_charge" and charge_ready:
		factor *= 1.0 + 0.25 * player.item_effects.passive_scale()
		charge_ready = false
	var physical_bonus := 0.4 * player.item_effects.passive_scale() if passive_id == "dog_bite" and attack_serial % 4 == 0 else 0.0
	var enchants := player.weapon_elements.duplicate()
	for element: int in enchants:
		enchants[element] = float(enchants[element]) / (1.0 + physical_bonus) * elemental_factor()
	var effects := player.hit_effects()
	effects["source_player"] = weakref(player)
	effects["attack_token"] = {"seen": {}, "combo": {}}
	var critical_chance := 1.0 if critical_time > 0 else minf(1, player.crit_chance + (0.08 * player.item_effects.passive_scale() if passive_id == "cat_crit" else 0.0))
	critical_time = 0
	return {"multiplier": player.damage_multiplier * factor * (1.0 + physical_bonus), "critical_chance": critical_chance, "elements": enchants, "effects": effects}

func hit_bonus(enemy: Enemy, effects: Dictionary) -> float:
	var result := 1.0
	if mark_time > 0 and marked_target != null and marked_target.get_ref() == enemy:
		result *= 1.15 if enemy.is_in_group("bosses") else 1.25
	if passive_id == "cat_execute" and enemy.health_component.current_health < enemy.health_component.max_health * 0.3:
		result *= 1.0 + 0.2 * player.item_effects.passive_scale()
	if passive_id == "mouse_ambush" and (enemy.slow_time > 0 or enemy.control_time > 0):
		result *= 1.0 + 0.15 * player.item_effects.passive_scale()
	if passive_id == "bunny_combo" and effects.has("attack_token"):
		var token: Dictionary = effects.attack_token
		var id := enemy.get_instance_id()
		if not token.combo.has(id):
			token.combo[id] = combo_target == id and combo_count >= 3
		if token.combo[id]:
			result *= 1.0 + 0.2 * player.item_effects.passive_scale()
	return result

func after_hit(enemy: Enemy, effects: Dictionary) -> void:
	player.item_effects.after_hit(effects)
	if passive_id != "bunny_combo" or not effects.has("attack_token"):
		return
	var seen: Dictionary = effects.attack_token.seen
	var id := enemy.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	if combo_target != id:
		combo_target = id
		combo_count = 0
	combo_count = 0 if combo_count >= 3 else combo_count + 1

func elemental_factor() -> float:
	return 1.0 + (0.15 * player.item_effects.passive_scale() if passive_id == "mouse_elements" else 0.0)

func pickup_factor() -> float:
	return 1.0 + (0.35 * player.item_effects.passive_scale() if passive_id == "mouse_collect" else 0.0)

func deal(enemy: Enemy, factor: float, element: int = Elements.Type.NONE, token: Dictionary = {}) -> bool:
	var amount := 8.0 * player.damage_multiplier * damage_factor() * factor
	var enchants := {}
	if element != Elements.Type.NONE:
		# -1 denotes a pure elemental hit, preserving counters and damage colors.
		enchants[element] = 1.0
		if passive_id == "mouse_elements":
			amount *= elemental_factor()
	var effects := player.hit_effects()
	effects["source_player"] = weakref(player)
	effects["pure_element"] = element
	effects["cast_token"] = cast_token if token.is_empty() else token
	return HitEffects.apply(enemy, amount, player.global_position.direction_to(enemy.global_position), 35, false, enchants, effects)

func incoming_damage(amount: float, contact: bool) -> float:
	if passive_id == "dog_hide" and contact:
		amount *= 1.0 - 0.2 * player.item_effects.passive_scale()
	if passive_id == "cat_guard" and no_hit_time >= 6:
		amount *= 1.0 - 0.3 * player.item_effects.passive_scale()
	no_hit_time = 0
	amount = player.item_effects.incoming_damage(amount)
	if shield_time > 0 and shield > 0:
		var absorbed := minf(amount, shield)
		shield -= absorbed
		amount -= absorbed
		DamageNumber.spawn(get_tree().current_scene, player.global_position + Vector2(0, -34), absorbed, false, Color("8fd5ee"), "盾 ")
	return amount

func lure_for(enemy: Enemy) -> Vector2:
	if enemy.is_in_group("bosses"):
		return player.global_position
	for effect in get_tree().get_nodes_in_group("player_skill_effects"):
		if effect.caster == player and effect.kind == "decoy" and not effect.is_queued_for_deletion() and effect.global_position.distance_to(enemy.global_position) < 200 and clear_ray(enemy.global_position, effect.global_position):
			return effect.global_position
	return player.global_position

func experience_gain(amount: int) -> int:
	if passive_id != "mouse_collect":
		return amount
	var gain := amount * (1.0 + 0.15 * player.item_effects.passive_scale()) + experience_remainder
	var whole := floori(gain + 0.000001)
	experience_remainder = gain - whole
	return whole

func _draw() -> void:
	if player.item_effects.shield > 0 and player.item_effects.shield_time > 0:
		draw_arc(Vector2(0, -8), 22, 0, TAU, 24, Color("c7a2ff"), 2)
	if shield > 0 and shield_time > 0:
		draw_arc(Vector2(0, -8), 19, 0, TAU, 24, Color("90d9ef"), 2)
	if charge_ready:
		for index in 4:
			draw_rect(Rect2(Vector2.RIGHT.rotated(index * PI / 2) * 18 + Vector2(-1, -8), Vector2(2, 2)), Color("dbffe4"))
