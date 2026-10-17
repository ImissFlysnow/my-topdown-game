extends DungeonBoss
class_name ThornSovereign

const MINION_SCENE = preload("res://Scene/Enemies/enemy.tscn")
const MINION_DATA = preload("res://Data/Enemies/slime.tres")
@export var minion_limit: int = 4
var skill_index: int = 0
var casting_skill: int = 0

func _start_slam() -> void:
	casting_skill = skill_index % 3
	skill_index += 1
	_begin_cast(["荆棘召唤", "缠根花阵", "毒种扇射"][casting_skill], 0.9)
	_warning_circle(global_position, 44, 0.9)
	if casting_skill == 1:
		var side := global_position.direction_to(target.global_position).orthogonal()
		for index in 3:
			var hazard := _hazard(target.global_position + side * (index - 1) * 95, 32, 0.55, 1.0, 3.6, 0.9)
			hazard.slow_factor = 0.65
			hazard.slow_seconds = 0.8

func _tick_special_state(delta: float) -> void:
	_move_in_room(delta, Vector2.ZERO)
	state_time -= delta
	if state_time > 0:
		return
	if casting_skill == 0:
		_summon_servants()
	elif casting_skill == 2:
		_fan(7 if enraged else 5, global_position.direction_to(target.global_position), 1.15, 115, 0.75)
		if enraged:
			_ring(6, 90, 0.55)
	_recover(0.65)

func _prune_minions() -> void:
	# Remove invalid references before passing them to typed parameters.
	# Mutating in place also preserves Array[Enemy] after nodes are freed.
	for index in range(owned_minions.size() - 1, -1, -1):
		if not is_instance_valid(owned_minions[index]):
			owned_minions.remove_at(index)
		elif owned_minions[index].health_component.is_dead:
			owned_minions.remove_at(index)

func _summon_servants() -> void:
	_prune_minions()
	var count := mini(3 if enraged else 2, minion_limit - owned_minions.size())
	for index in count:
		var point := global_position + Vector2.RIGHT.rotated(age + index * PI) * 95
		if room_bounds.has_area():
			point = point.clamp(room_bounds.position + Vector2(10, 10), room_bounds.end - Vector2(10, 10))
		var marker := SpawnMarker.new()
		marker.data = MINION_DATA
		marker.remaining = skill_duration(0.85)
		marker.add_to_group("enemy_attacks")
		marker.finished.connect(_spawn_servant)
		_attach_attack(marker, point)

func _spawn_servant(point: Vector2, minion_data: EnemyData) -> void:
	if health_component.is_dead:
		return
	_prune_minions()
	if owned_minions.size() >= minion_limit:
		return
	var minion := MINION_SCENE.instantiate() as Enemy
	minion.data = minion_data.duplicate() as EnemyData
	minion.data.experience = 0
	minion.data.coins = 0
	minion.element = element
	minion.health_scale = 1 + floor_number * 0.12
	minion.damage_scale = damage_scale * 0.65
	minion.room_bounds = room_bounds
	minion.room_id = room_id
	minion.position = point
	minion.target = target
	minion.dungeon = dungeon
	get_parent().add_child(minion)
	minion.add_to_group("boss_minions")
	owned_minions.append(minion)

func status_text() -> String:
	if state == State.CAST:
		return super.status_text()
	_prune_minions()
	return "召唤仆从 · 绿圈会减速 · 仆从 %d/%d" % [owned_minions.size(), minion_limit]
