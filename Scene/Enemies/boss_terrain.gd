extends Node2D
class_name BossTerrain

enum Kind { THORNS, WATER, FIRE, SHIELD_BURST }
const THORN_TEXTURE = preload("res://Assets/BossEffects/thorn.png")
const WATER_TEXTURE = preload("res://Assets/BossEffects/water.png")
const FIRE_TEXTURE = preload("res://Assets/BossEffects/fire.png")
const BURST_TEXTURE = preload("res://Assets/BossEffects/shield_burst.png")
var kind: Kind = Kind.WATER
var target: Player
var boss: WeakRef
var room := Rect2()
var regions: Array[Rect2] = []
var tile_size: float = 24
var warning_time: float = 0.8
var active_duration: float = 5
var radius: float = 140
var damage: float = 1
var age: float = 0
var exposure: float = 0
var resolved := false
var cancelled := false
var bodies: Array[StaticBody2D] = []
var fire_tiles: Dictionary[Vector2i, float] = {}

func _ready() -> void:
	add_to_group("enemy_attacks")
	add_to_group("boss_terrain")
	z_index = -1 if kind in [Kind.WATER, Kind.FIRE] else 2

func cancel() -> void:
	cancelled = true
	for body in bodies:
		if is_instance_valid(body):
			body.collision_layer = 0
	set_physics_process(false)
	hide()
	queue_free()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if cancelled or is_queued_for_deletion():
		return
	if not is_instance_valid(target) or target.health_component.is_dead:
		cancel()
		return
	age += delta
	if kind == Kind.FIRE:
		_tick_fire(delta)
	elif age >= warning_time + active_duration:
		cancel()
	elif age >= warning_time:
		match kind:
			Kind.THORNS:
				if not resolved:
					resolved = true
					_create_barriers()
				_tick_thorns(delta)
			Kind.WATER:
				if contains_point(target.global_position):
					target.apply_slow(0.18, 0.55)
			Kind.SHIELD_BURST:
				if not resolved:
					resolved = true
					if contains_point(target.global_position):
						target.take_hit(damage, global_position.direction_to(target.global_position), 100, false, Elements.Type.EARTH)
	queue_redraw()

func contains_point(point: Vector2) -> bool:
	if room.has_area() and not room.has_point(point):
		return false
	if kind == Kind.SHIELD_BURST:
		return point.distance_to(global_position) <= radius
	if kind == Kind.FIRE:
		return fire_tiles.has(Vector2i((point / tile_size).floor()))
	for region in regions:
		if region.has_point(to_local(point)):
			return true
	return false

func _create_barriers() -> void:
	for region in regions:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = region.size
		shape.shape = rectangle
		body.add_child(shape)
		body.position = region.get_center()
		add_child(body)
		bodies.append(body)
		if boss != null and is_instance_valid(boss.get_ref()):
			body.add_collision_exception_with(boss.get_ref())
			boss.get_ref().add_collision_exception_with(body)
		# A player who misses the warning can escape instead of being embedded.
		if region.grow(8).has_point(to_local(target.global_position)):
			body.add_collision_exception_with(target)
			target.add_collision_exception_with(body)

func _tick_thorns(delta: float) -> void:
	for index in bodies.size():
		if not regions[index].grow(8).has_point(to_local(target.global_position)):
			bodies[index].remove_collision_exception_with(target)
			target.remove_collision_exception_with(bodies[index])
	if contains_point(target.global_position):
		exposure -= delta
		target.apply_slow(0.18, 0.7)
		if exposure <= 0:
			exposure = 0.8
			target.take_hit(damage, Vector2.ZERO, 0, false, Elements.Type.WOOD)
	else:
		exposure = 0

func add_fire_segment(start: Vector2, end: Vector2) -> void:
	var steps := maxi(1, ceili(start.distance_to(end) / (tile_size * 0.35)))
	for index in range(steps + 1):
		var cell := Vector2i((start.lerp(end, float(index) / steps) / tile_size).floor())
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size
		if not room.has_area() or room.has_point(center):
			fire_tiles[cell] = age + active_duration
	queue_redraw()

func _tick_fire(delta: float) -> void:
	for cell: Vector2i in fire_tiles.keys():
		if fire_tiles[cell] <= age:
			fire_tiles.erase(cell)
	if fire_tiles.is_empty():
		cancel()
		return
	if contains_point(target.global_position):
		exposure += delta
		if exposure >= 1.0 - 0.000001:
			exposure = maxf(0, exposure - 1.0)
			target.take_hit(1.0, Vector2.ZERO, 0, false, Elements.Type.FIRE)
	else:
		exposure = 0

func _draw() -> void:
	if cancelled:
		return
	var frame := int(age * 9) % 6
	if kind == Kind.SHIELD_BURST:
		_draw_burst()
		return
	var color := Color("a8db84") if kind == Kind.THORNS else Color("77d8ed")
	if kind == Kind.FIRE:
		for cell: Vector2i in fire_tiles:
			var point := to_local((Vector2(cell) + Vector2(0.5, 0.5)) * tile_size)
			draw_texture_rect_region(FIRE_TEXTURE, Rect2(point - Vector2.ONE * tile_size * 0.5, Vector2.ONE * tile_size), Rect2(frame * 24, 0, 24, 24))
		return
	var warning := age < warning_time
	for region in regions:
		if warning:
			draw_rect(region, Color(color, 0.13 + 0.1 * sin(age * 14)))
			draw_rect(region, color, false, 1)
		var texture: Texture2D = THORN_TEXTURE if kind == Kind.THORNS else WATER_TEXTURE
		var growth := clampf((age - warning_time + 0.4) / 0.4, 0, 1) if kind == Kind.THORNS else 1.0
		for y in ceili(region.size.y / tile_size):
			for x in ceili(region.size.x / tile_size):
				var cell := Rect2(region.position + Vector2(x, y) * tile_size, Vector2.ONE * tile_size)
				cell.size = cell.size.min(region.end - cell.position)
				if kind == Kind.THORNS and warning:
					var along := (x + 0.5) / ceili(region.size.x / tile_size) if region.size.x > region.size.y else (y + 0.5) / ceili(region.size.y / tile_size)
					if minf(along, 1.0 - along) * 2 > growth:
						continue
				var tint := Color(1, 1, 1, 0.35 if warning else 1.0)
				draw_texture_rect_region(texture, cell, Rect2(frame * 24, 0, 24, 24), tint)
		if kind == Kind.WATER:
			draw_rect(region, Color(color, 0.6), false, 1)

func _draw_burst() -> void:
	var color := Color("ffd690")
	if age < warning_time:
		var progress := clampf(age / warning_time, 0, 1)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.08 * progress))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, 2)
		draw_arc(Vector2.ZERO, radius * progress, 0, TAU, 64, Color(color, 0.7), 2)
		for index in 12:
			var point := Vector2.RIGHT.rotated(index * TAU / 12.0) * radius
			draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), color)
	else:
		var progress := clampf((age - warning_time) / active_duration, 0, 0.999)
		var frame := int(progress * 6)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.25 * (1.0 - progress)))
		draw_texture_rect_region(BURST_TEXTURE, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), Rect2(frame * 64, 0, 64, 64), Color(1, 1, 1, 1.0 - progress * 0.65))
