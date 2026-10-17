extends DungeonBoss
class_name BastionWarden

@export_range(0.1, 1.0, 0.05) var shield_ratio: float = 0.35
@export_range(0.0, 0.2, 0.01) var shield_phase_bonus: float = 0.05
@export_range(0.1, 1.0, 0.05) var shield_damage_factor: float = 0.75
@export var vulnerable_duration: float = 1.0
@export var vulnerable_multiplier: float = 1.25
@export var exposed_duration: float = 8.0
@export_range(0.1, 1.0, 0.05) var repair_fraction: float = 0.6
@export var reforge_duration: float = 1.8
@export var shield_move_factor: float = 0.85
var shield_health: float = 0
var shield_capacity: float = 1
var pulse_timer: float = 1.5
var skill_index: int = 1
var casting_skill: int = 0
var phase_index: int = 1
var shield_volley_timer: float = -1
var shield_aim := Vector2.ZERO
var volley_timer: float = 0
var volleys_left: int = 0
var volley_direction := Vector2.RIGHT
var exposed_time: float = 0
var reforge_full := true
var strafe_sign: float = 1

func _ready() -> void:
	super._ready()
	_activate_shield()

func _physics_process(delta: float) -> void:
	var was_exposed := exposed_time > 0
	super._physics_process(delta)
	if health_component.is_dead or not is_instance_valid(target) or target.health_component.is_dead:
		return
	if was_exposed and exposed_time > 0:
		exposed_time = maxf(0, exposed_time - delta)
		if exposed_time <= 0:
			_begin_reforge(false)

func _activate_shield(full: bool = true) -> void:
	shield_capacity = maxf(8, health_component.max_health * (shield_ratio + (phase_index - 1) * shield_phase_bonus))
	shield_health = shield_capacity * (1.0 if full else repair_fraction)
	exposed_time = 0
	state = State.SHIELDED
	pulse_timer = skill_duration(1.5)
	shield_volley_timer = -1
	volleys_left = 0
	skill_name = "玄岩护体"
	boss_sprite.speed_scale = 1.0
	boss_sprite.play("idle")
	queue_redraw()

func _break_shield() -> void:
	shield_health = 0
	state = State.VULNERABLE
	state_time = vulnerable_duration
	exposed_time = maxf(vulnerable_duration, exposed_duration)
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	shield_volley_timer = -1
	volleys_left = 0
	_clear_owned_attacks()
	boss_sprite.speed_scale = 1.0
	boss_sprite.play("idle")
	queue_redraw()

func _begin_reforge(full: bool) -> void:
	reforge_full = full
	exposed_time = 0
	state = State.REFORGE
	state_time = skill_duration(reforge_duration)
	skill_name = "岩甲重铸" if full else "岩甲修复"
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	shield_volley_timer = -1
	volleys_left = 0
	slow_time = 0
	burn_time = 0
	burn_tick_damage = 0
	_clear_owned_attacks()
	boss_sprite.speed_scale = 1.0 / skill_time_multiplier
	boss_sprite.play("attack")
	_warning_circle(global_position, 56, reforge_duration)
	queue_redraw()

func _phase_threshold() -> float:
	return health_component.max_health * (3 - phase_index) / 3.0

func _phase_damage_scale(total_damage: float) -> float:
	if phase_index >= 3 or total_damage <= 0:
		return 1.0
	var budget := maxf(0, health_component.current_health - _phase_threshold())
	return minf(1.0, budget / total_damage)

func _check_phase_transition() -> void:
	if phase_index < 3 and health_component.current_health <= _phase_threshold() + 0.0001:
		phase_index += 1
		_begin_reforge(true)

func take_hit(amount: float, hit_direction: Vector2 = Vector2.ZERO, force: float = 90, critical: bool = false, enchantments: Dictionary = {}) -> bool:
	if health_component.is_dead or state == State.REFORGE:
		return false
	if state == State.SHIELDED:
		var damage := total_hit_damage(amount, enchantments) * shield_damage_factor
		if damage <= 0:
			return false
		var absorbed := minf(shield_health, damage)
		shield_health = maxf(0, shield_health - damage)
		_on_damage_dealt(absorbed)
		flash_timer = 0.1
		hurt_sound.play()
		DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -85), absorbed, critical, Color("9fdfff"), "盾 ")
		if shield_health <= 0:
			_break_shield()
		queue_redraw()
		return true
	amount *= vulnerable_multiplier if state == State.VULNERABLE else 1.0
	# A large hit stops at the visible phase boundary, including all elements.
	amount *= _phase_damage_scale(total_hit_damage(amount, enchantments))
	var accepted := super.take_hit(amount, hit_direction, force, critical, enchantments)
	_check_phase_transition()
	return accepted

func take_burn_damage(amount: float) -> void:
	if not can_receive_status_effects():
		return
	amount *= vulnerable_multiplier if state == State.VULNERABLE else 1.0
	amount *= _phase_damage_scale(amount * Elements.multiplier(Elements.Type.FIRE, element))
	super.take_burn_damage(amount)
	_check_phase_transition()

func can_receive_status_effects() -> bool:
	return state != State.REFORGE and super.can_receive_status_effects()

func _start_slam() -> void:
	casting_skill = 1 if skill_index % 2 == 1 else 2
	skill_index += 1
	var quake_name := "十字地裂" if phase_index >= 2 else "三重地裂"
	_begin_cast("岩枪连射" if casting_skill == 1 else quake_name, 0.9)
	_warning_circle(global_position, 42, 0.9)
	if casting_skill == 1:
		volley_direction = global_position.direction_to(target.global_position)
		volleys_left = 3 if enraged else 2
		volley_timer = state_time
		_warning_line(global_position, global_position + volley_direction * 220, 0.9, 24)
	else:
		var direction := target.movement.normalized()
		if direction == Vector2.ZERO:
			direction = global_position.direction_to(target.global_position).orthogonal()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var center := target.global_position
		for index in 3:
			_hazard(center + direction * ((index - 1) * 85), 36, 1.0, 0.9 + index * 0.24)
		if phase_index >= 2:
			for side in [-1, 1]:
				_hazard(center + direction.orthogonal() * side * 85, 32, 0.85, 1.5)

func _tick_special_state(delta: float) -> void:
	if state == State.SHIELDED:
		var direction := global_position.direction_to(target.global_position)
		var speed := data.move_speed * shield_move_factor * (1.25 if enraged else 1.0)
		_move_in_room(delta, direction * speed if global_position.distance_to(target.global_position) > 38 else Vector2.ZERO)
		boss_sprite.speed_scale = 1.0
		boss_sprite.play("walk" if velocity.length() > 5 else "idle")
		boss_sprite.flip_h = direction.x < 0
		if shield_volley_timer >= 0:
			shield_volley_timer -= delta
			if shield_volley_timer <= 0:
				_fan(5 if phase_index >= 2 else 3, global_position.direction_to(shield_aim), 0.9, 120, 0.65)
				shield_volley_timer = -1
		pulse_timer -= delta
		if pulse_timer <= 0:
			pulse_timer = skill_duration(1.7 if enraged or phase_index == 3 else 2.3)
			_hazard(global_position, 78, 0.8, 0.85)
			shield_aim = target.global_position
			shield_volley_timer = skill_duration(0.85)
			_warning_line(global_position, global_position + direction * 220, 0.85, 24)
		return
	if state == State.REFORGE:
		_move_in_room(delta, Vector2.ZERO)
		state_time -= delta
		if state_time <= 0:
			_activate_shield(reforge_full)
	elif state == State.VULNERABLE:
		_move_in_room(delta, Vector2.ZERO)
		state_time -= delta
		if state_time <= 0:
			# Only the short break stagger is stationary. Immediately resume
			# pursuit and a counterattack while the core remains exposed.
			state = State.CHASE
			skill_time = 0.12
			boss_sprite.play("walk")
	else:
		var direction := global_position.direction_to(target.global_position)
		var motion := direction.orthogonal() * strafe_sign if casting_skill == 1 else direction
		_move_in_room(delta, motion * data.move_speed * (0.65 if enraged else 0.5))
		if is_on_wall():
			strafe_sign *= -1
		boss_sprite.flip_h = direction.x < 0
		state_time -= delta
		if casting_skill == 1:
			volley_timer -= delta
			if volley_timer <= 0 and volleys_left > 0:
				var offset := 0.12 if volleys_left % 2 == 0 else -0.12
				_fan(7 if enraged else 5, volley_direction.rotated(offset), 1.2, 140, 0.85)
				volleys_left -= 1
				volley_timer = skill_duration(0.36)
			if volleys_left <= 0:
				_recover(0.75)
		elif state_time <= 0:
			if enraged:
				_ring(10, 95, 0.65)
			_recover(0.75)

func shield_value() -> float:
	return shield_health if state == State.SHIELDED else 0

func shield_maximum() -> float:
	return shield_capacity

func status_text() -> String:
	var stage := "阶段 %d/3 · " % phase_index
	if state == State.REFORGE:
		return stage + ("满盾重铸" if reforge_full else "修复六成盾") + " %.1f秒 · 暂时免伤" % maxf(0, state_time)
	if state == State.SHIELDED:
		return stage + "厚甲追击 · 本体免伤 · 盾 %.0f/%.0f" % [shield_health, shield_capacity]
	if state == State.VULNERABLE:
		return stage + "破盾虚弱 %.1f秒 · 即将反击 · ×%.2f" % [maxf(0, state_time), vulnerable_multiplier]
	if exposed_time > 0:
		return stage + "失甲 %.1f秒 · " % exposed_time + super.status_text()
	return stage + super.status_text()

func _draw() -> void:
	super._draw()
	if state == State.REFORGE:
		var progress := clampf(1.0 - state_time / skill_duration(reforge_duration), 0, 1)
		draw_circle(Vector2(0, -24), 48 * progress, Color(0.55, 0.8, 1, 0.2))
		draw_arc(Vector2(0, -24), 48 * progress, 0, TAU, 40, Color("9fdfff"), 3)
	elif state == State.SHIELDED:
		draw_circle(Vector2(0, -24), 48, Color(0.55, 0.8, 1, 0.1))
		draw_arc(Vector2(0, -24), 48, age, age + TAU, 40, Color("9fdfff"), 3)
	elif state == State.VULNERABLE:
		draw_arc(Vector2(0, -6), 37, 0, TAU, 36, Color("fff0bd"), 2)
