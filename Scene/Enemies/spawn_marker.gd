extends Node2D
class_name SpawnMarker

signal finished(point: Vector2, enemy_data: EnemyData)
var data: EnemyData
var remaining: float = 0.95
var age: float = 0.0

func _ready() -> void:
	add_to_group("spawn_markers")
	z_index = -1

func _process(delta: float) -> void:
	remaining -= delta
	age += delta
	queue_redraw()
	if remaining <= 0.0:
		finished.emit(global_position, data)
		queue_free()

func _draw() -> void:
	var alpha := 0.45 + 0.3 * sin(age * 15.0)
	draw_circle(Vector2.ZERO, 15, Color(0.9, 0.3, 0.4, alpha * 0.25))
	draw_arc(Vector2.ZERO, 18.0 - age * 6.0, 0, TAU, 32, Color(1.0, 0.5, 0.5, alpha), 2.0)
	draw_line(Vector2(-6, -6), Vector2(6, 6), Color(1.0, 0.5, 0.5, alpha), 1.0)
	draw_line(Vector2(-6, 6), Vector2(6, -6), Color(1.0, 0.5, 0.5, alpha), 1.0)
