extends CharacterBody2D
class_name Player

signal energy_changed(current: int, maximum: int)

const ENERGY_PER_CELL: int = 10
const ENERGY_CELLS: int = 3
const MAX_ENERGY: int = ENERGY_PER_CELL * ENERGY_CELLS
const ENERGY_REGEN_INTERVAL: float = 0.25 # Testing balance: 8x the previous collection rate.

@export var data: PlayerData
@onready var visuals: Node2D = $Visuals
@onready var anim_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_controller: WeaponController = $WeaponController

var can_move := true
var movement: Vector2
var direction: Vector2
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var crit_chance: float = 0.1
var pickup_radius: float = 65.0
var coins: int = 0
var experience: int = 0
var level: int = 1
var inventory: Dictionary[String, int] = {}
var invulnerability: float = 0.0
var knockback_velocity := Vector2.ZERO
var weapon_elements: Dictionary[int, float] = {}
var affinity: int = Elements.Type.NONE
var slow_time: float = 0
var slow_factor: float = 1
var projectile_pierce: int = 0
var ranged_damage_factor: float = 1.0
var hunter_bonus: float = 0.0
var frost_stacks: int = 0
var ember_stacks: int = 0
var greedy_pouches: int = 0
var arena: Arena
var energy: int = 0
var energy_charge_started := false
var energy_regen_remaining: float = ENERGY_REGEN_INTERVAL
var skills: SkillController
var item_effects := SkillItemEffects.new()

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	health_component.init_health(data.max_hp)
	item_effects.player = self
	skills = SkillController.new()
	skills.player = self
	add_child(skills)
	_update_health_ui()

func _physics_process(delta: float) -> void:
	_tick_energy(delta)
	slow_time = maxf(0, slow_time - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	visuals.modulate = Color(1.0, 0.45, 0.45, 0.65) if invulnerability > 0.0 and fmod(invulnerability, 0.12) > 0.06 else Color.WHITE
	if not can_move or skills.dash_remaining > 0:
		return
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	movement = direction * data.move_speed * speed_multiplier * skills.speed_factor() * (slow_factor if slow_time > 0 else 1.0)
	anim_sprite.play("move" if direction != Vector2.ZERO else "idle")
	velocity = movement + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	var move_start := global_position
	move_and_slide()
	if direction != Vector2.ZERO:
		item_effects.record_movement(move_start, global_position)
	if absf(direction.x) > 0.05:
		visuals.scale.x = 1.0 if direction.x > 0.0 else -1.0

func _can_charge_energy() -> bool:
	return is_instance_valid(arena) and arena.phase == Arena.Phase.COMBAT and not health_component.is_dead and not get_tree().paused

func _reset_energy_charge() -> void:
	energy_charge_started = false
	energy_regen_remaining = item_effects.regen_interval()

func _tick_energy(delta: float) -> void:
	if get_tree().paused:
		return
	if not _can_charge_energy() or energy >= MAX_ENERGY:
		_reset_energy_charge()
	elif energy_charge_started:
		energy_regen_remaining = maxf(0, energy_regen_remaining - delta)

func record_damage_dealt(amount: float) -> void:
	if amount <= 0 or not _can_charge_energy() or energy >= MAX_ENERGY:
		return
	if not energy_charge_started:
		energy_charge_started = true
		energy_regen_remaining = item_effects.regen_interval()
		return
	# Only a real damaging hit grants energy. Idle time cannot bank points.
	if energy_regen_remaining > 0.000001:
		return
	energy = mini(MAX_ENERGY, energy + 1)
	energy_regen_remaining = item_effects.regen_interval()
	energy_changed.emit(energy, MAX_ENERGY)
	if energy == MAX_ENERGY:
		_reset_energy_charge()

func consume_energy(amount: int) -> bool:
	if amount <= 0 or amount > energy or health_component.is_dead:
		return false
	energy -= amount
	energy_changed.emit(energy, MAX_ENERGY)
	return true

func restore_energy(amount: int) -> void:
	if amount <= 0 or health_component.is_dead:
		return
	energy = mini(MAX_ENERGY, energy + amount)
	energy_changed.emit(energy, MAX_ENERGY)
	if energy >= MAX_ENERGY:
		_reset_energy_charge()

func take_hit(amount: float, hit_direction: Vector2 = Vector2.ZERO, force: float = 70.0, critical: bool = false, incoming_element: int = Elements.Type.NONE, contact: bool = false) -> bool:
	if invulnerability > 0.0 or health_component.is_dead:
		return false
	invulnerability = 0.7
	knockback_velocity = Vector2.ZERO if skills.shield_time > 0 else hit_direction * force
	amount *= Elements.multiplier(incoming_element, affinity)
	amount = skills.incoming_damage(amount, contact)
	if amount <= 0:
		return true
	var color := Elements.color(incoming_element) if incoming_element != Elements.Type.NONE else Color("ff706b")
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -28), amount, critical, color, "", Elements.relation(incoming_element, affinity))
	# Enemy damage enters through take_hit; event sacrifices bypass this path.
	if amount >= health_component.current_health and item_effects.prevent_death():
		return true
	health_component.take_damage(amount)
	return true

func apply_slow(duration: float, factor: float) -> void:
	if skills.passive_id == "bunny_light":
		factor = lerpf(1.0, factor, 1.0 - 0.3 * item_effects.passive_scale())
	if slow_time <= 0:
		slow_factor = clampf(factor, 0.3, 1)
	else:
		slow_factor = minf(slow_factor, clampf(factor, 0.3, 1))
	slow_time = maxf(slow_time, duration)

func experience_needed() -> int:
	return 10 + level * 5

func has_ranged_weapon() -> bool:
	return is_instance_valid(weapon_controller.current_weapon) and weapon_controller.current_weapon.data.bullet_scene != null

func hit_effects() -> Dictionary:
	return {"hunter_bonus": hunter_bonus, "frost_chance": minf(0.8, frost_stacks * 0.2), "burn_chance": minf(0.8, ember_stacks * 0.2)}

func can_collect_item(item: ItemData) -> bool:
	if item.kind == ItemData.Kind.SHOP_HEALING and health_component.current_health >= health_component.max_health:
		return false
	if item.kind == ItemData.Kind.ECHO_CAPACITOR and skills.active_id not in ["bunny_dash", "bunny_blade", "dog_roar", "dog_charge", "mouse_bomb", "mouse_vortex", "mouse_mines"]:
		return false
	return not health_component.is_dead and item.kind != ItemData.Kind.HEAL and (not item.requires_ranged or has_ranged_weapon()) and item_effects.can_collect(item)

func collect_item(item: ItemData) -> bool:
	if not can_collect_item(item):
		return false
	var old_interval := item_effects.regen_interval()
	item_effects.collect(item)
	if item.kind == ItemData.Kind.ENERGY_CRYSTAL and energy_charge_started:
		energy_regen_remaining *= item_effects.regen_interval() / old_interval
	match item.kind:
		ItemData.Kind.EXPERIENCE:
			experience += skills.experience_gain(int(item.amount))
			while experience >= experience_needed():
				experience -= experience_needed()
				level += 1
				damage_multiplier += 0.1
				health_component.max_health += 1.0
				health_component.heal(1.0)
				_update_health_ui()
				EventBus.on_item_collected.emit("升级！Lv.%d · 伤害 +10%% · 生命上限 +1 · 当前生命 +1" % level)
		ItemData.Kind.COIN:
			coins += int(item.amount)
		ItemData.Kind.SHOP_HEALING:
			health_component.heal(health_component.max_health * item.amount)
		ItemData.Kind.DAMAGE:
			damage_multiplier = damage_multiplier * (1.0 + item.amount) if item.proportional else damage_multiplier + item.amount
		ItemData.Kind.SPEED:
			speed_multiplier = minf(1.75, speed_multiplier * (1.0 + item.amount) if item.proportional else speed_multiplier + item.amount)
		ItemData.Kind.ATTACK_SPEED:
			cooldown_multiplier = maxf(0.25, cooldown_multiplier / (1.0 + item.amount) if item.proportional else cooldown_multiplier * (1.0 - item.amount))
		ItemData.Kind.MAGNET:
			pickup_radius = pickup_radius * (1.0 + item.amount) if item.proportional else pickup_radius + item.amount
		ItemData.Kind.LIGHT_GRIP:
			cooldown_multiplier = maxf(0.25, cooldown_multiplier / (1.0 + item.amount))
			damage_multiplier *= 0.95
		ItemData.Kind.ARMOR_PIERCING:
			projectile_pierce += maxi(1, roundi(item.amount))
			ranged_damage_factor *= 0.90
		ItemData.Kind.HEADHUNTER:
			hunter_bonus += item.amount
		ItemData.Kind.FROST_SHARD:
			frost_stacks += 1
			weapon_elements[Elements.Type.WATER] = weapon_elements.get(Elements.Type.WATER, 0.0) + item.amount
		ItemData.Kind.EMBER_MARK:
			ember_stacks += 1
		ItemData.Kind.GREEDY_POUCH:
			greedy_pouches += maxi(1, roundi(item.amount))
	if item.kind >= ItemData.Kind.DAMAGE and item.kind != ItemData.Kind.SHOP_HEALING:
		inventory[item.item_name] = inventory.get(item.item_name, 0) + 1
	if item.kind != ItemData.Kind.EXPERIENCE and item.kind != ItemData.Kind.COIN:
		EventBus.on_item_collected.emit(item.item_name + " · " + item.description.replace("\n", " · "))
	EventBus.on_inventory_updated.emit()
	return true

func _update_health_ui() -> void:
	EventBus.on_player_health_updated.emit(health_component.current_health, health_component.max_health)

func _on_health_component_on_unit_damaged(_amount: float) -> void:
	_update_health_ui()

func _on_health_component_on_unit_dead() -> void:
	can_move = false
	velocity = Vector2.ZERO
	anim_sprite.play("dead")
	weapon_controller.hide()
	EventBus.on_player_died.emit()

func _on_health_component_on_unit_healed(amount: float) -> void:
	_update_health_ui()
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -25), amount, false, Color("8ff5b0"), "+")
