extends Node2D
class_name Pickup

var data: ItemData
var target: Player
var dungeon: DungeonGenerator
var age: float = 0.0
var attracted := false
var collected := false

func _ready() -> void:
	add_to_group("pickups")
	z_index = 1

func _physics_process(delta: float) -> void:
	age += delta
	queue_redraw()
	if collected or not is_instance_valid(target) or target.health_component.is_dead:
		return
	if data.kind == ItemData.Kind.HEAL and target.health_component.current_health >= target.health_component.max_health:
		attracted = false
		return
	var point := target.global_position + Vector2(0, -5)
	var distance := global_position.distance_to(point)
	var radius := target.pickup_radius if data.kind <= ItemData.Kind.COIN else 24.0
	if data.kind <= ItemData.Kind.COIN:
		radius *= target.skills.pickup_factor()
	if distance <= radius:
		attracted = true
	if attracted:
		# Ray check keeps magnetised loot from crossing dungeon walls.
		var ray := PhysicsRayQueryParameters2D.create(global_position, point, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			attracted = false
			return
		global_position = global_position.move_toward(point, (160.0 + age * 60.0) * delta)
		if global_position.distance_to(point) < 12.0 and target.collect_item(data):
			collected = true
			queue_free()

func _draw() -> void:
	if not data:
		return
	var color := Color("8cf0ce") if data.kind == ItemData.Kind.EXPERIENCE else Color("f4d58a")
	if data.rarity >= 0:
		color = data.tint
	draw_circle(Vector2.ZERO, 8, Color(color, 0.12))
	var y := sin(age * 4.0) * 2.0
	if data.kind == ItemData.Kind.EXPERIENCE:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -6 + y), Vector2(4, -1 + y), Vector2(0, 4 + y), Vector2(-4, -1 + y)]), color)
		draw_line(Vector2(0, -4 + y), Vector2(0, 1 + y), Color("e1fff3"), 1.0)
	elif data.icon:
		var size := Vector2(14, 14) if data.kind == ItemData.Kind.COIN else Vector2(20, 20)
		draw_texture_rect(data.icon, Rect2(-size * 0.5 + Vector2(0, y), size), false, data.tint)
		if data.rarity >= 0:
			draw_arc(Vector2(0, y), 12, 0, TAU, 24, color, 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(-10, -15 + y), "%d%%" % roundi(data.amount * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)
