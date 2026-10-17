extends DungeonBoss
class_name TideArchmage

var skill_index: int = 0
var casting_skill: int = 0
var volleys_left: int = 0
var volley_timer: float = 0
var burst_index: int = 0
var locked_direction := Vector2.RIGHT

func _chase_player(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	var direction := global_position.direction_to(target.global_position)
	if distance < 145:
		direction = -direction
	elif distance <= 230:
		direction = direction.orthogonal() * (1 if sin(age * 0.7) >= 0 else -1)
	_move_in_room(delta, direction * data.move_speed * (1.1 if enraged else 0.8))

func _start_slam() -> void:
	casting_skill = skill_index % 3
	skill_index += 1
	locked_direction = global_position.direction_to(target.global_position)
	_begin_cast(["冰锥齐射", "潮汐螺旋", "追踪水珠"][casting_skill], 0.75)
	_warning_circle(global_position, 38, 0.75)
	_warning_line(global_position, global_position + locked_direction * 230, 0.75)
	volleys_left = (4 if enraged else 3) if casting_skill < 2 else 1
	volley_timer = 0
	burst_index = 0

func _tick_special_state(delta: float) -> void:
	_move_in_room(delta, Vector2.ZERO)
	if state_time > 0:
		state_time -= delta
		return
	volley_timer -= delta
	if volley_timer > 0:
		return
	if casting_skill == 0:
		_fan(9 if enraged else 7, locked_direction, 1.05, 150, 0.8)
	elif casting_skill == 1:
		_ring(12, 112, 0.75, burst_index * 0.17, 0.35 if burst_index % 2 == 0 else -0.35)
	else:
		var count := 5 if enraged else 3
		for index in count:
			var direction := locked_direction.rotated(lerpf(-0.45, 0.45, float(index) / (count - 1)))
			_shoot(direction, 164, 0.9, 4.0, 1.5)
		if enraged:
			_hazard(target.global_position, 38, 0.65, 1.1)
	volleys_left -= 1
	burst_index += 1
	volley_timer = skill_duration(0.32)
	if volleys_left <= 0:
		_recover(0.7)

func status_text() -> String:
	if state == State.CAST:
		return "%s · %s" % [skill_name, "蓄力 %.1f 秒" % maxf(0, state_time) if state_time > 0 else "远程连射中"]
	return "远程弹幕 · 保持移动，避开追踪水珠"
