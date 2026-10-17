extends Node2D

var caster: Player
var cast_token: Dictionary = {}
var kind: String = "flash"
var lifetime: float = 1
var age: float = 0
var direction := Vector2.RIGHT
var factor: float = 1
var radius: float = 65
var element: int = Elements.Type.NONE
var follow: WeakRef
var origin := Vector2.ZERO
var hits: Dictionary[int, bool] = {}
var returning := false
var pulses: int = 0
var exploded := false

func _ready() -> void:
	add_to_group("player_skill_effects")
	add_to_group("player_projectiles")
	origin = global_position
	z_index = 3

func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or not caster.skills.in_combat():
		queue_free()
		return
	age += delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	match kind:
		"blade":
			var start := global_position
			if age >= 0.45 and not returning:
				returning = true
				hits.clear()
			if returning:
				direction = global_position.direction_to(caster.global_position)
				if global_position.distance_to(caster.global_position) < 9:
					queue_free()
					return
			var end := start + direction * 310 * delta
			var ray := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start, end, 1))
			if not ray.is_empty():
				if returning:
					queue_free()
					return
				returning = true
				hits.clear()
				end = ray.position - direction * 3
			global_position = end
			for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
				if not hits.has(enemy.get_instance_id()) and Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end).distance_to(enemy.global_position) < 15 + 5 * enemy.data.size_scale and caster.skills.clear_ray(start, enemy.global_position):
					hits[enemy.get_instance_id()] = true
					caster.skills.deal(enemy, factor, Elements.Type.NONE, cast_token)
		"smoke":
			for enemy in caster.skills.enemies_at(global_position, radius):
				enemy.apply_slow(0.15, 0.7)
		"vortex":
			for enemy in caster.skills.enemies_at(global_position, radius):
				if enemy.can_receive_status_effects() and not enemy.is_in_group("bosses"):
					var motion := enemy.global_position.direction_to(global_position) * minf(80 * delta, enemy.global_position.distance_to(global_position))
					if not enemy.test_move(enemy.global_transform, motion):
						enemy.global_position += motion
			if pulses < 3 and age >= 0.3 + pulses * 0.6:
				pulses += 1
				for enemy in caster.skills.enemies_at(global_position, radius):
					caster.skills.deal(enemy, factor, Elements.Type.NONE, cast_token)
		"bomb":
			if age >= 0.35 and not exploded:
				explode(65, false)
		"mine":
			if not exploded and age > 0.3 and not caster.skills.enemies_at(global_position, 21).is_empty():
				explode(43, true)
		"mark":
			if follow == null or not is_instance_valid(follow.get_ref()) or follow.get_ref().health_component.is_dead:
				queue_free()
				return
			global_position = follow.get_ref().global_position
	queue_redraw()

func explode(size: float, slow: bool) -> void:
	exploded = true
	radius = size
	lifetime = 0.35
	for enemy in caster.skills.enemies_at(global_position, radius):
		if caster.skills.deal(enemy, factor, element, cast_token) and slow:
			enemy.apply_slow(1.5, 0.75)

func projectile_speed_factor(point: Vector2) -> float:
	return 0.65 if kind == "smoke" and point.distance_to(global_position) <= radius else 1.0

func _draw() -> void:
	var color := Color("a3dfbb")
	if caster.data.id == "Cat":
		color = Color("c5a5ef")
	elif caster.data.id == "Dog":
		color = Color("f0c687")
	elif caster.data.id == "Mouse":
		color = Elements.color(element) if element != Elements.Type.NONE else Color("85d4ea")
	match kind:
		"decoy":
			draw_texture_rect(caster.data.icon, Rect2(-13, -24, 26, 26), false, Color(color, 0.65))
		"blade":
			var start := age * 16
			draw_arc(Vector2.ZERO, 12, start, start + PI * 1.4, 12, color, 3)
		"mark":
			draw_rect(Rect2(-13, -30, 26, 26), color, false, 2)
			draw_line(Vector2(-5, -40), Vector2(0, -35), color, 2)
			draw_line(Vector2(0, -35), Vector2(5, -40), color, 2)
		"smoke", "vortex":
			draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
			for index in 3:
				draw_arc(Vector2.ZERO, radius - index * 15, age * (1 + index) + index, age * (1 + index) + index + PI * 1.3, 24, Color(color, 0.45), 2)
		"mine", "bomb":
			if exploded:
				draw_circle(Vector2.ZERO, radius, Color(color, lifetime * 0.6))
				draw_arc(Vector2.ZERO, radius * (1.35 - lifetime), 0, TAU, 24, Color(color, lifetime * 2), 3)
			else:
				draw_rect(Rect2(-5, -4, 10, 8), color)
				draw_rect(Rect2(-2, -7, 4, 3), Color("fbe3ab"))
				if kind == "bomb":
					draw_arc(Vector2.ZERO, 65, 0, TAU, 24, Color(color, 0.4), 1)
		"flash":
			draw_arc(Vector2.ZERO, radius * minf(1, age * 4), 0, TAU, 28, Color(color, minf(1, lifetime * 2)), 3)
