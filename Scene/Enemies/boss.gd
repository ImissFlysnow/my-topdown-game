extends Enemy
class_name DungeonBoss

enum State { CHASE, WINDUP, RECOVER, CAST, SHIELDED, VULNERABLE, BLINK, DASH, REFORGE }
@export var render_size: float = 92
@export var normal_skill_interval: float = 3.0
@export var enraged_skill_interval: float = 2.2
@export_range(0.1, 2.0, 0.05) var skill_time_multiplier: float = 0.5
@onready var boss_sprite: AnimatedSprite2D = $Visuals/BossAnimation
var state: State = State.CHASE
var state_time: float = 0
var skill_time: float = 2.5
var enraged := false
var floor_number: int = 1
var skill_name: String = "地震重击"
var owned_minions: Array[Enemy] = []

func _ready() -> void:
	super._ready()
	skill_time = skill_duration(skill_time)
	add_to_group("bosses")
	sprite.hide()
	visuals.scale = Vector2.ONE
	var frame := boss_sprite.sprite_frames.get_frame_texture("idle", 0)
	boss_sprite.scale = Vector2.ONE * (render_size / frame.get_width())
	boss_sprite.position = Vector2(0, -render_size * 0.42)
	boss_sprite.play("idle")
	$Visuals/Shadow.scale = Vector2(3.5, 2.0)

func _physics_process(delta: float) -> void:
	if health_component.is_dead or not is_instance_valid(target) or target.health_component.is_dead:
		return
	_tick_status_effects(delta)
	if health_component.is_dead:
		return
	age += delta
	attack_timer = maxf(0, attack_timer - delta)
	flash_timer = maxf(0, flash_timer - delta)
	enraged = health_component.current_health < health_component.max_health * 0.5
	boss_sprite.modulate = Color(2, 2, 2) if flash_timer > 0 else Color.WHITE.lerp(Elements.color(element), 0.32 if enraged else 0.18)
	if flash_timer <= 0 and slow_time > 0:
		boss_sprite.modulate = boss_sprite.modulate.lerp(Elements.color(Elements.Type.WATER), 0.35)
	if state == State.CHASE:
		boss_sprite.speed_scale = 1.0
		_chase_player(delta)
		boss_sprite.play("walk" if velocity.length() > 5 else "idle")
		boss_sprite.flip_h = target.global_position.x < global_position.x
		skill_time -= delta
		if skill_time <= 0:
			_start_slam()
	elif state == State.WINDUP or state == State.RECOVER:
		_move_in_room(delta, Vector2.ZERO)
		state_time -= delta
		if state_time <= 0:
			if state == State.WINDUP:
				if enraged:
					_radial_burst()
				_recover(0.55)
			else:
				state = State.CHASE
				skill_time = skill_duration(enraged_skill_interval if enraged else normal_skill_interval)
	else:
		_tick_special_state(delta)
	if state in [State.CHASE, State.SHIELDED]:
		_contact_damage()
	queue_redraw()

func _chase_player(delta: float) -> void:
	var speed := data.move_speed * (1.25 if enraged else 1.0)
	_move_in_room(delta, global_position.direction_to(target.global_position) * speed)

func _move_in_room(delta: float, desired_velocity: Vector2) -> void:
	velocity = desired_velocity * status_speed_multiplier() + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 450 * delta)
	move_and_slide()
	if room_bounds.has_area():
		global_position = global_position.clamp(room_bounds.position, room_bounds.end)

func _contact_damage() -> void:
	if attack_timer <= 0 and global_position.distance_to(target.global_position) < 17 + 4 * data.size_scale:
		target.take_hit(data.contact_damage * damage_scale, global_position.direction_to(target.global_position), 70, false, element, true)
		attack_timer = 0.8

func _tick_special_state(_delta: float) -> void:
	_recover(0.3)

func skill_duration(duration: float) -> float:
	return duration * skill_time_multiplier

func _recover(duration: float) -> void:
	state = State.RECOVER
	state_time = skill_duration(duration)
	velocity = Vector2.ZERO

func _begin_cast(name: String, duration: float) -> void:
	skill_name = name
	state = State.CAST
	state_time = skill_duration(duration)
	velocity = Vector2.ZERO
	boss_sprite.speed_scale = 1.0 / skill_time_multiplier
	boss_sprite.play("attack")

func _attach_attack(attack: Node2D, point: Vector2) -> void:
	attack.position = point
	attack.set_meta("boss_owner", get_instance_id())
	get_parent().add_child(attack)

func combat_room_rect() -> Rect2:
	return dungeon.room_world_rect(room_id) if is_instance_valid(dungeon) and room_id >= 0 else room_bounds

func _terrain(kind: BossTerrain.Kind, point: Vector2, warning: float, duration: float) -> BossTerrain:
	var terrain := BossTerrain.new()
	terrain.kind = kind
	terrain.target = target
	terrain.boss = weakref(self)
	terrain.room = combat_room_rect()
	terrain.tile_size = dungeon.cell_size if is_instance_valid(dungeon) else 24
	terrain.warning_time = warning
	terrain.active_duration = duration
	_attach_attack(terrain, point)
	return terrain

func _warning_circle(point: Vector2, radius: float, duration: float) -> void:
	var warning := BossTelegraph.new()
	warning.radius = radius
	warning.duration = skill_duration(duration)
	warning.element = element
	_attach_attack(warning, point)

func _warning_line(point: Vector2, end: Vector2, duration: float, width: float = 25) -> void:
	var warning := BossTelegraph.new()
	warning.line_end = end - point
	warning.kind = BossTelegraph.Kind.LINE
	warning.width = width
	warning.duration = skill_duration(duration)
	warning.element = element
	_attach_attack(warning, point)

func _shoot(direction: Vector2, speed: float, factor: float = 1, lifetime: float = 3, homing: float = 0, curve: float = 0) -> EnemyProjectile:
	var projectile := EnemyProjectile.new()
	projectile.target = target
	projectile.element = element
	projectile.damage = data.contact_damage * damage_scale * factor
	projectile.speed = speed
	projectile.direction = direction.normalized()
	projectile.lifetime = lifetime
	projectile.homing_turn_rate = homing
	projectile.curve_rate = curve
	_attach_attack(projectile, global_position + Vector2(0, -7) + projectile.direction * 28)
	return projectile

func _fan(count: int, direction: Vector2, spread: float, speed: float, factor: float = 1) -> void:
	for index in count:
		var angle := lerpf(-spread * 0.5, spread * 0.5, float(index) / maxf(1, count - 1))
		_shoot(direction.rotated(angle), speed, factor)

func _ring(count: int, speed: float, factor: float = 1, offset: float = 0, curve: float = 0) -> void:
	for index in count:
		_shoot(Vector2.RIGHT.rotated(offset + TAU * float(index) / count), speed, factor, 3, 0, curve)

func _hazard(point: Vector2, radius: float, factor: float = 1.25, warning: float = 0.85, active: float = 0.25, interval: float = 0) -> GroundHazard:
	var hazard := GroundHazard.new()
	hazard.target = target
	hazard.damage = data.contact_damage * damage_scale * factor
	hazard.element = element
	hazard.radius = radius
	hazard.warning_time = skill_duration(warning)
	hazard.active_duration = active
	hazard.tick_interval = interval
	if room_bounds.has_area():
		point = point.clamp(room_bounds.position + Vector2(25, 25), room_bounds.end - Vector2(25, 25))
	_attach_attack(hazard, point)
	return hazard

func _start_slam() -> void:
	skill_name = "地震重击"
	state = State.WINDUP
	state_time = skill_duration(0.85)
	velocity = Vector2.ZERO
	boss_sprite.speed_scale = 1.0 / skill_time_multiplier
	boss_sprite.play("attack")
	var radius := 68.0 + floor_number * 2.0
	if floor_number == 1:
		radius *= 0.9
	_hazard(target.global_position, radius)

func _radial_burst() -> void:
	_ring(8, 95 + floor_number * 8)

func status_text() -> String:
	if state == State.WINDUP or state == State.CAST:
		return "%s · 蓄力 %.1f 秒" % [skill_name, maxf(0, state_time)]
	return "半血狂暴 · 留意技能预警" if enraged else "留意地面预警，横向移动躲避"

func can_receive_status_effects() -> bool:
	return super.can_receive_status_effects() and state != State.SHIELDED and collision_layer != 0

func shield_value() -> float:
	return 0

func shield_maximum() -> float:
	return 1

func _clear_owned_attacks(preserve_break_burst: bool = false) -> void:
	for attack in get_tree().get_nodes_in_group("enemy_attacks"):
		if attack.get_meta("boss_owner", 0) == get_instance_id():
			if preserve_break_burst and attack.get_meta("shield_break_burst", false):
				continue
			if attack.has_method("cancel"):
				attack.cancel()
			attack.set_process(false)
			attack.set_physics_process(false)
			if attack.is_in_group("spawn_markers"):
				attack.remove_from_group("spawn_markers")
			attack.queue_free()

func _die() -> void:
	remove_from_group("enemies")
	remove_from_group("bosses")
	set_physics_process(false)
	collision_layer = 0
	visuals.modulate.a = 1
	_clear_owned_attacks()
	for minion in owned_minions:
		if is_instance_valid(minion):
			minion.remove_from_group("enemies")
			minion.set_physics_process(false)
			minion.collision_layer = 0
			minion.queue_free()
	EventBus.on_enemy_killed.emit(global_position, data.experience, data.coins)
	boss_sprite.speed_scale = 1.0
	boss_sprite.play("death")
	await boss_sprite.animation_finished
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.2)
	tween.tween_callback(queue_free)
