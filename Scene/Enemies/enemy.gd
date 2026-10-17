extends CharacterBody2D
class_name Enemy

@export var data: EnemyData
@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Visuals/Sprite2D
@onready var visuals: Node2D = $Visuals
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
var target: Player
var dungeon: DungeonGenerator
var room_id: int = -1
var room_bounds := Rect2()
var element: int = Elements.Type.NONE
var damage_scale: float = 1.0
var move_speed_scale: float = 1.0
var knockback_velocity := Vector2.ZERO
var path := PackedVector2Array()
var path_index: int = 0
var path_timer: float = 0.0
var attack_timer: float = 0.0
var flash_timer: float = 0.0
var age: float = 0.0
var health_scale: float = 1.0
var slow_time: float = 0.0
var slow_factor: float = 1.0
var burn_time: float = 0.0
var burn_tick_timer: float = 0.0
var burn_tick_damage: float = 0.0
var control_time: float = 0.0
var frightened := false
var fear_origin := Vector2.ZERO
static var element_font: Font

func _ready() -> void:
	if not element_font:
		element_font = PixelFonts.get_font(8)
	add_to_group("enemies")
	if data.elite:
		add_to_group("elite_enemies")
	collision_layer = 4
	collision_mask = 1
	sprite.texture = data.texture
	visuals.scale = Vector2.ONE * data.size_scale
	if element == Elements.Type.NONE:
		element = data.element
	sprite.modulate = data.tint
	var shape := CircleShape2D.new()
	shape.radius = 7.0 * data.size_scale
	$CollisionShape2D.shape = shape
	health_component.init_health(data.max_health * health_scale)
	health_component.on_unit_damaged.connect(_on_damage_dealt)
	health_component.on_unit_dead.connect(_die)
	path_timer = randf_range(0.0, 0.5)

func _physics_process(delta: float) -> void:
	if health_component.is_dead or not is_instance_valid(target) or target.health_component.is_dead:
		return
	_tick_status_effects(delta)
	if health_component.is_dead:
		return
	age += delta
	attack_timer = maxf(0.0, attack_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	sprite.modulate = Color(2.5, 2.5, 2.5) if flash_timer > 0.0 else data.tint
	if flash_timer <= 0 and slow_time > 0:
		sprite.modulate = sprite.modulate.lerp(Elements.color(Elements.Type.WATER), 0.45)
	path_timer -= delta
	var point := target.skills.lure_for(self)
	var direction := Vector2.ZERO
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -7), point + Vector2(0, -7), 1)
	var clear := get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	if clear:
		direction = global_position.direction_to(point)
	elif is_instance_valid(dungeon):
		if path_timer <= 0.0:
			path = dungeon.find_path(global_position, point)
			path_index = 1 if path.size() > 1 else 0
			path_timer = randf_range(0.4, 0.7)
		if path_index < path.size():
			if global_position.distance_to(path[path_index]) < 9.0:
				path_index += 1
			if path_index < path.size():
				direction = global_position.direction_to(path[path_index])
	var separation := Vector2.ZERO
	for other: Node2D in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance > 0.01 and distance < 19.0 * data.size_scale:
			separation += offset / distance * (1.0 - distance / (19.0 * data.size_scale))
	if control_time > 0:
		direction = fear_origin.direction_to(global_position) if frightened else Vector2.ZERO
		separation = Vector2.ZERO
	velocity = (direction + separation * 0.7).limit_length(1.0) * data.move_speed * move_speed_scale * status_speed_multiplier() + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 450.0 * delta)
	move_and_slide()
	if room_bounds.has_area():
		global_position = global_position.clamp(room_bounds.position, room_bounds.end)
	if absf(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0
	sprite.position.y = -11.0 + sin(age * 10.0) * 1.3
	if control_time <= 0 and clear and global_position.distance_to(target.global_position) < 17.0 + 4.0 * data.size_scale and attack_timer <= 0.0:
		target.take_hit(data.contact_damage * damage_scale, global_position.direction_to(target.global_position), 70.0, false, element, true)
		attack_timer = 0.8
	queue_redraw()

func can_receive_status_effects() -> bool:
	return not health_component.is_dead

func status_speed_multiplier() -> float:
	return slow_factor if slow_time > 0 else 1.0

func apply_slow(duration: float, factor: float) -> void:
	if not can_receive_status_effects():
		return
	if is_in_group("bosses"):
		factor = lerpf(1.0, factor, 0.5)
	slow_factor = minf(slow_factor, factor) if slow_time > 0 else factor
	slow_time = maxf(slow_time, duration)
	queue_redraw()

func apply_burn(total_damage: float) -> void:
	if not can_receive_status_effects() or total_damage <= 0:
		return
	if burn_time <= 0:
		burn_tick_timer = 0.5
	burn_time = 2.0
	burn_tick_damage = maxf(burn_tick_damage, total_damage / 4.0)
	queue_redraw()

func apply_control(duration: float, fear: bool, origin: Vector2) -> void:
	if not can_receive_status_effects():
		return
	if is_in_group("bosses"):
		apply_slow(duration, 0.8)
		return
	control_time = maxf(control_time, duration)
	frightened = fear
	fear_origin = origin

func _tick_status_effects(delta: float) -> void:
	control_time = maxf(0, control_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	if burn_time <= 0:
		return
	var active_delta := minf(delta, burn_time)
	burn_time = maxf(0, burn_time - active_delta)
	burn_tick_timer -= active_delta
	while burn_tick_timer <= 0.000001:
		burn_tick_timer += 0.5
		take_burn_damage(burn_tick_damage)
		if health_component.is_dead:
			burn_time = 0
			break
	if burn_time <= 0:
		burn_tick_damage = 0
	queue_redraw()

func take_burn_damage(amount: float) -> void:
	if not can_receive_status_effects():
		return
	amount *= Elements.multiplier(Elements.Type.FIRE, element)
	DamageNumber.spawn(get_tree().current_scene, global_position + Vector2(0, -27 * data.size_scale), amount, false, Elements.color(Elements.Type.FIRE), "燃 ", Elements.relation(Elements.Type.FIRE, element))
	flash_timer = 0.07
	health_component.take_damage(amount)

func total_hit_damage(amount: float, enchantments: Dictionary = {}) -> float:
	var total := 0.0 if enchantments.has(-1) else amount
	for attack_element: int in enchantments:
		if attack_element < 0:
			continue
		total += amount * maxf(0, float(enchantments[attack_element])) * Elements.multiplier(attack_element, element)
	return total

func take_hit(amount: float, hit_direction: Vector2 = Vector2.ZERO, force: float = 90.0, critical: bool = false, enchantments: Dictionary = {}) -> bool:
	if health_component.is_dead:
		return false
	knockback_velocity += hit_direction * force * data.knockback_resistance
	flash_timer = 0.1
	hurt_sound.pitch_scale = randf_range(0.9, 1.1)
	hurt_sound.play()
	var point := global_position + Vector2(0, -27 * data.size_scale)
	if not enchantments.has(-1):
		DamageNumber.spawn(get_tree().current_scene, point, amount, critical)
	var total_damage := total_hit_damage(amount, enchantments)
	var index := 1
	for attack_element: int in enchantments:
		if attack_element < 0:
			continue
		var bonus := amount * maxf(0, float(enchantments[attack_element])) * Elements.multiplier(attack_element, element)
		if bonus <= 0:
			continue
		DamageNumber.spawn(get_tree().current_scene, point + Vector2(13, -15 * index), bonus, critical, Elements.color(attack_element), "", Elements.relation(attack_element, element))
		index += 1
	health_component.take_damage(total_damage)
	queue_redraw()
	return true

func _on_damage_dealt(amount: float) -> void:
	if is_instance_valid(target):
		target.record_damage_dealt(amount)

func _die() -> void:
	remove_from_group("enemies")
	set_physics_process(false)
	collision_layer = 0
	EventBus.on_enemy_killed.emit(global_position, data.experience, data.coins)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visuals, "scale", Vector2.ZERO, 0.16)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	if health_component.is_dead:
		return
	if burn_time > 0:
		draw_arc(Vector2(0, -4), 11 * data.size_scale, age * 3, age * 3 + TAU * 0.8, 24, Elements.color(Elements.Type.FIRE), 2)
	if slow_time > 0:
		draw_arc(Vector2(0, -4), 10 * data.size_scale, 0, TAU, 24, Elements.color(Elements.Type.WATER), 1.5)
	if data.elite:
		var elite_point := Vector2(13, -31 * data.size_scale)
		draw_colored_polygon(PackedVector2Array([elite_point + Vector2(0, -5), elite_point + Vector2(4, 0), elite_point + Vector2(0, 5), elite_point + Vector2(-4, 0)]), Color("ffe08a"))
	if element != Elements.Type.NONE:
		var point := Vector2(0, -31 * data.size_scale)
		draw_circle(point, 6, Color("25202e"))
		draw_circle(point, 4, Elements.color(element))
		draw_string(element_font, point + Vector2(-4, 3), Elements.title(element), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("201a29"))
	if health_component.current_health >= health_component.max_health:
		return
	var width := 22.0 * data.size_scale
	var rect := Rect2(Vector2(-width / 2, -40 * data.size_scale), Vector2(width, 3))
	draw_rect(rect, Color("251f31"))
	rect.size.x *= health_component.current_health / health_component.max_health
	draw_rect(rect, Elements.color(element) if element != Elements.Type.NONE else Color("f38b8b"))
