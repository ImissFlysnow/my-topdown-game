extends Node2D
class_name BossTelegraph

enum Kind { CIRCLE, LINE }
var kind: Kind = Kind.CIRCLE
var radius: float = 35
var line_end := Vector2(140, 0)
var width: float = 25
var element: int = Elements.Type.FIRE
var duration: float = 0.65
var age: float = 0

func _ready() -> void:
	add_to_group("enemy_attacks")
	z_index = 2

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Elements.color(element)
	var progress := clampf(age / maxf(0.01, duration), 0, 1)
	if kind == Kind.CIRCLE:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.13))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, color, 2)
		draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 40, Color(color, 0.6), 2)
	else:
		draw_line(Vector2.ZERO, line_end, Color(color, 0.13 + progress * 0.12), width)
		draw_line(Vector2.ZERO, line_end, Color(color, 0.9), 2)
		var direction := line_end.normalized()
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([line_end, line_end - direction * 15 + side * 8, line_end - direction * 15 - side * 8]), color)
		draw_arc(Vector2.ZERO, 12, 0, TAU, 24, color, 2)
