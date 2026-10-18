extends DungeonBoss
class_name EmberStalker

@export var dash_speed: float = 520
var skill_index: int = 0
var casting_skill: int = 0
var blink_destination := Vector2.ZERO
var dash_direction := Vector2.RIGHT
var dashes_left: int = 0
var teleporting := false
var dash_hit := false
var fire_trail: BossTerrain

func _leave_fire(start: Vector2, end: Vector2) -> void:
	if start.distance_squared_to(end) < 0.01:
		return
	if not is_instance_valid(fire_trail) or fire_trail.cancelled or fire_trail.is_queued_for_deletion():
		fire_trail = _terrain(BossTerrain.Kind.FIRE, Vector2.ZERO, 0, 5.0)
	fire_trail.add_fire_segment(start, end)

func _start_slam() -> void:
	casting_skill = skill_index % 3
	skill_index += 1
	if casting_skill == 2:
		_begin_cast("影火落点", 0.95)
		for index in 3:
			_hazard(target.global_position + Vector2((index - 1) * 85, 0), 34, 0.65, 0.95 + index * 0.12, 1.7, 0.85)
	else:
		dashes_left = 1 if casting_skill == 0 else (3 if enraged else 2)
		skill_name = "影步突袭" if casting_skill == 0 else "烈焰连斩"
		_prepare_dash(casting_skill == 0, 0.65)

func _choose_blink_destination() -> Vector2:
	var best := global_position
	var best_distance := 0.0
	for index in 8:
		var point := target.global_position + Vector2.RIGHT.rotated(age + index * TAU / 8) * 135
		if room_bounds.has_area():
			point = point.clamp(room_bounds.position + Vector2(15, 15), room_bounds.end - Vector2(15, 15))
		if is_instance_valid(dungeon) and not dungeon.is_floor(point):
			continue
		var distance := point.distance_squared_to(target.global_position)
		if distance > best_distance:
			best_distance = distance
			best = point
	return best

func _prepare_dash(blink: bool, warning: float) -> void:
	state = State.BLINK
	state_time = skill_duration(warning)
	teleporting = blink
	blink_destination = _choose_blink_destination() if blink else global_position
	dash_direction = blink_destination.direction_to(target.global_position)
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.RIGHT
	visuals.modulate.a = 0.18 if blink else 1.0
	collision_layer = 0 if blink else 4
	boss_sprite.speed_scale = 1.0 / skill_time_multiplier
	boss_sprite.play("attack")
	var endpoint := blink_destination + dash_direction * dash_speed * 0.36
	if room_bounds.has_area():
		endpoint = endpoint.clamp(room_bounds.position, room_bounds.end)
	_warning_line(blink_destination, endpoint, warning)
	if blink:
		_warning_circle(blink_destination, 24, warning)

func _tick_special_state(delta: float) -> void:
	state_time -= delta
	if state == State.CAST:
		_move_in_room(delta, Vector2.ZERO)
		if state_time <= 0:
			_recover(0.65)
	elif state == State.BLINK:
		if state_time <= 0:
			global_position = blink_destination
			visuals.modulate.a = 1
			collision_layer = 4
			state = State.DASH
			state_time = skill_duration(0.36)
			dash_hit = false
	elif state == State.DASH:
		var previous := global_position
		_move_in_room(delta, dash_direction * dash_speed / skill_time_multiplier)
		_leave_fire(previous, global_position)
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, previous, global_position)
		if not dash_hit and closest.distance_to(target.global_position) < 23:
			target.take_hit(data.contact_damage * damage_scale, dash_direction, 120, false, element)
			dash_hit = true
		if state_time <= 0:
			dashes_left -= 1
			if dashes_left > 0:
				_prepare_dash(false, 0.45)
			else:
				_recover(0.85)

func take_hit(amount: float, hit_direction: Vector2 = Vector2.ZERO, force: float = 90, critical: bool = false, enchantments: Dictionary = {}) -> bool:
	if state == State.BLINK and teleporting:
		return false
	return super.take_hit(amount, hit_direction, force, critical, enchantments)

func status_text() -> String:
	if state == State.BLINK:
		return "%s · 落点和方向已锁定，横向躲避" % skill_name
	if state == State.DASH:
		return "突进留下火径 · 连续踩火 1 秒扣 1 生命"
	return super.status_text()
