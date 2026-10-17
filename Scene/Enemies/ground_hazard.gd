extends Node2D
class_name GroundHazard

var target: Player
var radius: float = 66.0
var damage: float = 3.0
var element: int = Elements.Type.EARTH
var warning_time: float = 0.85
var active_duration: float = 0.25
var tick_interval: float = 0
var slow_factor: float = 1
var slow_seconds: float = 0
var age: float = 0.0
var resolved := false
var next_tick: float = 0

func _ready() -> void:
	z_index = 2
	add_to_group("enemy_attacks")

func _physics_process(delta: float) -> void:
	age += delta
	if age >= warning_time and not resolved:
		resolved = true
		_deal_damage()
		next_tick = age + tick_interval
	elif resolved and tick_interval > 0 and age >= next_tick and age <= warning_time + active_duration:
		_deal_damage()
		next_tick = age + tick_interval
	if age > warning_time + active_duration:
		queue_free()
	queue_redraw()

func _deal_damage() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= radius + 7:
		target.take_hit(damage, global_position.direction_to(target.global_position), 80 if tick_interval > 0 else 140, false, element)
		if slow_seconds > 0:
			target.apply_slow(slow_seconds, slow_factor)

func _draw() -> void:
	var color := Elements.color(element)
	var progress := clampf(age / maxf(0.01, warning_time), 0, 1)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.13 if not resolved else 0.3))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, 0.9), 2)
	draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 48, Color(color, 0.5), 2)
	draw_line(Vector2(-8, 0), Vector2(8, 0), color, 2)
	draw_line(Vector2(0, -8), Vector2(0, 8), color, 2)
