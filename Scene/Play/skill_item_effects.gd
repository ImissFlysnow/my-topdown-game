extends RefCounted
class_name SkillItemEffects

var player: Player
var counts: Dictionary[int, int] = {}
var haste_time: float = 0
var speed_time: float = 0
var gauntlet_time: float = 0
var gauntlet_attacks: int = 0
var shield_time: float = 0
var shield: float = 0
var movement_time: float = 0
var ring_hits: int = 0
var ring_ready := false
var battery_acquired := false

func count(kind: int) -> int:
	return counts.get(kind, 0)

func can_collect(item: ItemData) -> bool:
	if item.kind == ItemData.Kind.EMERGENCY_BATTERY and battery_acquired:
		return false
	return item.max_stacks <= 0 or count(item.kind) < item.max_stacks

func collect(item: ItemData) -> void:
	counts[item.kind] = count(item.kind) + 1
	if item.kind == ItemData.Kind.EMERGENCY_BATTERY:
		battery_acquired = true

func tick(delta: float) -> void:
	haste_time = maxf(0, haste_time - delta)
	speed_time = maxf(0, speed_time - delta)
	gauntlet_time = maxf(0, gauntlet_time - delta)
	shield_time = maxf(0, shield_time - delta)
	movement_time = maxf(0, movement_time - delta)
	if gauntlet_time <= 0:
		gauntlet_attacks = 0
	if shield_time <= 0:
		shield = 0

func clear_transient() -> void:
	haste_time = 0
	speed_time = 0
	gauntlet_time = 0
	gauntlet_attacks = 0
	shield_time = 0
	shield = 0
	movement_time = 0
	ring_hits = 0
	ring_ready = false

func record_movement(start: Vector2, end: Vector2) -> void:
	if start.distance_squared_to(end) > 0.01:
		movement_time = 0.1

func regen_interval() -> float:
	return Player.ENERGY_REGEN_INTERVAL / (1.0 + 0.25 * count(ItemData.Kind.ENERGY_CRYSTAL))

func passive_scale() -> float:
	return 1.0 + 0.2 * count(ItemData.Kind.TALENT_BADGE)

func speed_factor() -> float:
	return 1.0 + (0.2 * count(ItemData.Kind.SPEED_RIBBON) if speed_time > 0 else 0.0)

func cooldown_factor() -> float:
	return 1.0 / (1.0 + (0.15 * count(ItemData.Kind.HASTE_SIGIL) if haste_time > 0 else 0.0))

func on_cast() -> void:
	if count(ItemData.Kind.CAST_GAUNTLET) > 0:
		gauntlet_time = 4
		gauntlet_attacks = 3
	if count(ItemData.Kind.HASTE_SIGIL) > 0:
		haste_time = 4
	if count(ItemData.Kind.SPEED_RIBBON) > 0:
		speed_time = 3
	if count(ItemData.Kind.RESIDUAL_CHARM) > 0:
		shield = player.health_component.max_health * 0.1
		shield_time = 3
	if ring_ready:
		ring_ready = false
		ring_hits = 0
		player.restore_energy(2)

func begin_attack() -> float:
	var bonus := floori(player.energy / float(Player.ENERGY_PER_CELL)) * 0.04 * count(ItemData.Kind.ENERGY_MEDAL)
	if gauntlet_attacks > 0 and gauntlet_time > 0:
		bonus += 0.2 * count(ItemData.Kind.CAST_GAUNTLET)
		gauntlet_attacks -= 1
	return 1.0 + bonus

func after_hit(effects: Dictionary) -> void:
	if not player._can_charge_energy():
		return
	if effects.has("cast_token") and count(ItemData.Kind.ECHO_CAPACITOR) > 0:
		var token: Dictionary = effects.cast_token
		if not token.get("refunded", false):
			token["refunded"] = true
			player.restore_energy(2)
	if effects.has("attack_token") and count(ItemData.Kind.COMBO_RING) > 0:
		var token: Dictionary = effects.attack_token
		if not token.get("ring_counted", false):
			token["ring_counted"] = true
			if ring_ready:
				return
			ring_hits += 1
			if ring_hits >= 5:
				ring_ready = true
				player.skills._notify("连携指环已就绪 · 下次技能返还 2 能量")

func incoming_damage(amount: float) -> float:
	if movement_time > 0:
		amount *= 1.0 - 0.1 * count(ItemData.Kind.WIND_BOOTS)
	if shield_time > 0 and shield > 0:
		var absorbed := minf(amount, shield)
		shield -= absorbed
		amount -= absorbed
		DamageNumber.spawn(player.get_tree().current_scene, player.global_position + Vector2(0, -38), absorbed, false, Color("c7a2ff"), "盾 ")
	return amount

func prevent_death() -> bool:
	if count(ItemData.Kind.EMERGENCY_BATTERY) <= 0:
		return false
	counts[ItemData.Kind.EMERGENCY_BATTERY] = 0
	player.inventory.erase("应急电池")
	player.health_component.current_health = player.health_component.max_health * 0.2
	player.invulnerability = 2
	player.knockback_velocity = Vector2.ZERO
	player.slow_time = 0
	player.restore_energy(5)
	player._update_health_ui()
	EventBus.on_inventory_updated.emit()
	player.skills._notify("应急电池已消耗 · 恢复至 20% 生命 · 能量 +5")
	return true
