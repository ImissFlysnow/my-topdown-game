extends Node2D
class_name DungeonGenerator

enum RoomType { SHOP, CHALLENGE, EVENT, BOSS }
const ROOM_NAMES = ["商店", "挑战", "事件", "Boss"]
const NEIGHBORS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ATLAS = preload("res://01.基础资源/Assets/Sprites/Tiles/tilemap_packed.png")
@export var generation_seed: int = 0
@export var cell_size: int = 24
@export var grid_size := Vector2i(96, 80)
@export_range(3, 7, 2) var corridor_width: int = 5
var connections: Array[Vector2i] = []
var actual_seed: int
var rng := RandomNumberGenerator.new()
var floors: Dictionary[Vector2i, int] = {}
var walls: Dictionary[Vector2i, bool] = {}
var rooms: Array[Rect2i] = []
var room_types: Array[int] = []
var safe_cells: Array[Vector2i] = []
var spawn_position := Vector2.ZERO
var navigation := AStarGrid2D.new()
var floor_texture := AtlasTexture.new()
var decoration_cells: Dictionary[Vector2i, int] = {}
var sealed_rooms: Dictionary[int, Array] = {}
var gate_bodies: Dictionary[int, StaticBody2D] = {}

func _ready() -> void:
	z_index = -10
	floor_texture.atlas = ATLAS
	floor_texture.region = Rect2(16, 16, 16, 16)

func generate(seed_value: int = 0) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	floors.clear()
	walls.clear()
	rooms.clear()
	room_types.clear()
	safe_cells.clear()
	decoration_cells.clear()
	sealed_rooms.clear()
	gate_bodies.clear()
	connections.clear()
	grid_size = Vector2i(maxi(grid_size.x, 96), maxi(grid_size.y, 80))
	actual_seed = seed_value if seed_value != 0 else (generation_seed if generation_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi())
	rng.seed = actual_seed
	room_types.assign([RoomType.SHOP, RoomType.CHALLENGE, RoomType.EVENT, RoomType.CHALLENGE, RoomType.CHALLENGE, RoomType.BOSS])
	_place_rooms()
	for index in rooms.size():
		var room := rooms[index]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				floors[Vector2i(x, y)] = index
	_connect_layout()
	for cell: Vector2i in floors:
		var safe := true
		for offset: Vector2i in NEIGHBORS:
			if not floors.has(cell + offset):
				safe = false
				walls[cell + offset] = true
		if safe:
			safe_cells.append(cell)
		if rng.randf() < 0.017:
			decoration_cells[cell] = rng.randi_range(0, 2)
	_build_collision()
	_build_navigation()
	spawn_position = cell_to_world(rooms[0].get_center()) + Vector2(-80, 55)
	queue_redraw()

const ROOM_LAYOUTS = [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2)]
]
var layout_slots: Array[Vector2i] = []
var room_slots: Array[Vector2i] = []

func _place_rooms() -> void:
	# Compact layouts, rotated/mirrored with the seed. Shared row/column
	# centers allow adjacent rooms to connect with a single straight hall.
	layout_slots.clear()
	var turns := rng.randi_range(0, 3)
	var mirror := rng.randf() < 0.5
	var minimum := Vector2i(999, 999)
	for original: Vector2i in ROOM_LAYOUTS[rng.randi_range(0, ROOM_LAYOUTS.size() - 1)]:
		var slot := original
		for turn in turns:
			slot = Vector2i(-slot.y, slot.x)
		if mirror:
			slot.x = -slot.x
		minimum = minimum.min(slot)
		layout_slots.append(slot)
	var extent := Vector2i.ZERO
	for index in layout_slots.size():
		layout_slots[index] -= minimum
		extent = extent.max(layout_slots[index] + Vector2i.ONE)
	var candidates: Array[int] = []
	for index in 6:
		if _slots_connected_without(index):
			candidates.append(index)
	var boss_slot: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	var available: Array[int] = [0, 1, 2, 3, 4, 5]
	available.erase(boss_slot)
	room_slots.resize(6)
	room_slots[5] = layout_slots[boss_slot]
	for index in 5:
		var slot_index: int = available.pop_at(rng.randi_range(0, available.size() - 1))
		room_slots[index] = layout_slots[slot_index]
	var partition := Vector2i(grid_size.x / extent.x, grid_size.y / extent.y)
	var column_offsets: Array[int] = []
	var row_offsets: Array[int] = []
	for column in extent.x:
		column_offsets.append(rng.randi_range(-1, 1))
	for row in extent.y:
		row_offsets.append(rng.randi_range(-1, 1))
	rooms.resize(6)
	for index in 6:
		var maximum := partition - Vector2i.ONE * (corridor_width + 4)
		var min_size := Vector2i(16, 15)
		var max_size := Vector2i(mini(26, maximum.x), mini(24, maximum.y))
		if index == 5:
			max_size = Vector2i(mini(28, maximum.x), mini(26, maximum.y))
			min_size = Vector2i(mini(23, max_size.x), mini(21, max_size.y))
		elif index in [0, 2]:
			max_size = Vector2i(mini(22, maximum.x), mini(20, maximum.y))
		var room_size := Vector2i(rng.randi_range(min_size.x, max_size.x), rng.randi_range(min_size.y, max_size.y))
		var slot := room_slots[index]
		var center := slot * partition + Vector2i(partition.x / 2 + column_offsets[slot.x], partition.y / 2 + row_offsets[slot.y])
		rooms[index] = Rect2i(center - Vector2i(room_size.x / 2, room_size.y / 2), room_size)

func _slots_connected_without(excluded: int) -> bool:
	var first := 1 if excluded == 0 else 0
	var queue: Array[int] = [first]
	var seen: Dictionary[int, bool] = {first: true}
	var cursor := 0
	while cursor < queue.size():
		var slot := layout_slots[queue[cursor]]
		cursor += 1
		for index in 6:
			if index != excluded and not seen.has(index) and _adjacent_slots(slot, layout_slots[index]):
				seen[index] = true
				queue.append(index)
	return seen.size() == 5

func _adjacent_slots(first: Vector2i, second: Vector2i) -> bool:
	var offset := (first - second).abs()
	return offset.x + offset.y == 1

func _connect_layout() -> void:
	# Exactly five connections, no crossing halls or optional loops.
	# The boss occupies a non-articulation slot and is attached last.
	var connected: Array[int] = [0]
	var remaining: Array[int] = [1, 2, 3, 4]
	while not remaining.is_empty():
		var best := Vector2i(-1, -1)
		var score := INF
		for first in connected:
			for second in remaining:
				if not _adjacent_slots(room_slots[first], room_slots[second]):
					continue
				var candidate_score := Vector2(rooms[first].get_center() - rooms[second].get_center()).length() * rng.randf_range(0.8, 1.2)
				if candidate_score < score:
					score = candidate_score
					best = Vector2i(first, second)
		assert(best.x >= 0, "Non-boss room layout must remain connected")
		_connect_rooms(best.x, best.y)
		connected.append(best.y)
		remaining.erase(best.y)
	var boss_neighbor := -1
	var shortest := INF
	for index in 5:
		if not _adjacent_slots(room_slots[index], room_slots[5]):
			continue
		var distance := Vector2(rooms[index].get_center() - rooms[5].get_center()).length()
		if distance < shortest:
			shortest = distance
			boss_neighbor = index
	assert(boss_neighbor >= 0, "Boss room must have a neighboring room")
	_connect_rooms(boss_neighbor, 5)

func _connect_rooms(first: int, second: int) -> void:
	var start := rooms[first].get_center()
	var goal := rooms[second].get_center()
	assert(start.x == goal.x or start.y == goal.y, "Adjacent rooms must share a straight corridor axis")
	_carve_segment(start, goal)
	connections.append(Vector2i(mini(first, second), maxi(first, second)))

func _carve_segment(from: Vector2i, to: Vector2i) -> void:
	var cursor := from
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	while true:
		var half := corridor_width / 2
		for y in range(-half, half + 1):
			for x in range(-half, half + 1):
				var cell := cursor + Vector2i(x, y)
				if not floors.has(cell):
					floors[cell] = 6
		if cursor == to:
			break
		cursor += step

func room_at_world(point: Vector2, inset: int = 0) -> int:
	var cell := world_to_cell(point)
	for index in rooms.size():
		if rooms[index].grow(-inset).has_point(cell):
			return index
	return -1

func room_world_rect(index: int, inset: float = 0.0) -> Rect2:
	var room := rooms[index]
	return Rect2(Vector2(room.position * cell_size), Vector2(room.size * cell_size)).grow(-inset)

func room_center(index: int) -> Vector2:
	return cell_to_world(rooms[index].get_center())

func seal_room(index: int, sealed: bool) -> void:
	if sealed_rooms.has(index) == sealed:
		return
	if not sealed:
		for cell: Vector2i in sealed_rooms[index]:
			navigation.set_point_solid(cell, false)
		sealed_rooms.erase(index)
		var body: StaticBody2D = gate_bodies[index]
		remove_child(body)
		body.queue_free()
		gate_bodies.erase(index)
	else:
		var cells: Array = []
		var room := rooms[index]
		var body := StaticBody2D.new()
		body.name = "RoomGate%d" % index
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		for cell: Vector2i in floors:
			if not room.has_point(cell):
				continue
			for direction: Vector2i in NEIGHBORS:
				var neighbor := cell + direction
				if not room.has_point(neighbor) and floors.has(neighbor):
					cells.append(cell)
					break
		for cell: Vector2i in cells:
			navigation.set_point_solid(cell, true)
			var shape := RectangleShape2D.new()
			shape.size = Vector2.ONE * cell_size
			var collider := CollisionShape2D.new()
			collider.position = cell_to_world(cell)
			collider.shape = shape
			body.add_child(collider)
		sealed_rooms[index] = cells
		gate_bodies[index] = body
	queue_redraw()

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "DungeonWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in range(-1, grid_size.y + 1):
		var start := -999
		for x in range(-1, grid_size.x + 2):
			var occupied := walls.has(Vector2i(x, y))
			if occupied and start == -999:
				start = x
			elif not occupied and start != -999:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - start) * cell_size, cell_size)
				var collider := CollisionShape2D.new()
				collider.shape = shape
				collider.position = Vector2((start + x) * cell_size * 0.5, (y + 0.5) * cell_size)
				body.add_child(collider)
				start = -999

func _build_navigation() -> void:
	navigation.region = Rect2i(Vector2i.ZERO, grid_size)
	navigation.cell_size = Vector2.ONE * cell_size
	navigation.offset = Vector2.ONE * cell_size * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in grid_size.y:
		for x in grid_size.x:
			navigation.set_point_solid(Vector2i(x, y), not floors.has(Vector2i(x, y)))

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := world_to_cell(from)
	var goal := world_to_cell(to)
	if not floors.has(start):
		start = nearest_floor_cell(start)
	if not floors.has(goal):
		goal = nearest_floor_cell(goal)
	return navigation.get_point_path(start, goal)

func nearest_floor_cell(cell: Vector2i) -> Vector2i:
	var best := rooms[0].get_center()
	var distance := INF
	for candidate: Vector2i in safe_cells:
		var candidate_distance := Vector2(candidate - cell).length_squared()
		if candidate_distance < distance:
			distance = candidate_distance
			best = candidate
	return best

func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))

func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * cell_size

func is_floor(point: Vector2) -> bool:
	return floors.has(world_to_cell(point))

func random_floor_position() -> Vector2:
	return cell_to_world(safe_cells[rng.randi_range(0, safe_cells.size() - 1)])

func room_spawn_position(index: int, avoid: Vector2) -> Vector2:
	var room := rooms[index].grow(-3)
	var best := room_center(index)
	var best_distance := 0.0
	for attempt in 40:
		var cell := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		var point := cell_to_world(cell)
		var distance := point.distance_squared_to(avoid)
		if distance > best_distance:
			best = point
			best_distance = distance
		if distance > 100.0 * 100.0:
			return point
	return best

func _draw() -> void:
	draw_rect(Rect2(Vector2(-48, -48), Vector2(grid_size * cell_size) + Vector2(96, 96)), Color("1d1929"))
	var tints = [Color(0.58, 0.54, 0.59), Color(0.56, 0.51, 0.67), Color(0.47, 0.60, 0.62), Color(0.64, 0.46, 0.50)]
	for cell: Vector2i in floors:
		var rect := Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)
		var index: int = floors[cell]
		var tint: Color = tints[room_types[index]] if index < rooms.size() else Color(0.46, 0.43, 0.54)
		tint *= 0.94 + float(posmod(cell.x * 13 + cell.y * 7, 5)) * 0.025
		draw_texture_rect(floor_texture, rect, false, tint)
		draw_rect(rect, Color(0.12, 0.1, 0.18, 0.15), false, 1.0)
	for cell: Vector2i in walls:
		var rect := Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)
		draw_rect(rect, Color("312b40"))
		draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 6)), Color("51475f"))
		draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(cell_size - 2, 2), Color("8d7898"), 2.0)
		draw_line(rect.position + Vector2(2, cell_size - 3), rect.position + Vector2(cell_size - 2, cell_size - 3), Color("211c31"), 3.0)
	for index: int in sealed_rooms:
		for cell: Vector2i in sealed_rooms[index]:
			var rect := Rect2(Vector2(cell * cell_size), Vector2.ONE * cell_size)
			draw_rect(rect, Color("492e42"))
			for x in range(3, cell_size, 7):
				draw_line(rect.position + Vector2(x, 1), rect.position + Vector2(x, cell_size - 1), Color("d58275"), 3)
	for cell: Vector2i in decoration_cells:
		draw_circle(cell_to_world(cell), 1.5, Color("776285"))
