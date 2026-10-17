extends Control
class_name DungeonMinimap

var dungeon: DungeonGenerator
var player: Player
var arena: Arena
var background := StyleBoxFlat.new()

func _ready() -> void:
	background.bg_color = Color(0.12, 0.1, 0.18, 0.9)
	background.border_color = Color("62546e")
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(dungeon) or dungeon.floors.is_empty():
		return
	var factor := minf((size.x - 12) / dungeon.grid_size.x, (size.y - 12) / dungeon.grid_size.y)
	var origin := (size - Vector2(dungeon.grid_size) * factor) * 0.5
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	for cell: Vector2i in dungeon.floors:
		draw_rect(Rect2(origin + Vector2(cell) * factor, Vector2.ONE * maxf(1, factor)), Color("655c7d"))
	var colors := [Color("edcc85"), Color("b9a0df"), Color("85dbd2"), Color("ef9790")]
	for index in dungeon.rooms.size():
		var point := origin + Vector2(dungeon.rooms[index].get_center()) * factor
		var type: int = dungeon.room_types[index]
		var color: Color = colors[type]
		if is_instance_valid(arena) and arena.room_states[index] == Arena.RoomState.CLEARED:
			color = color.darkened(0.25)
		draw_circle(point, 4.5 if type == DungeonGenerator.RoomType.BOSS else 3.5, color)
		draw_string(ThemeDB.fallback_font, point + Vector2(-3, 3), ["S", "C", "?", "B"][type], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("241e30"))
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		draw_circle(origin + Vector2(dungeon.world_to_cell(enemy.global_position)) * factor, 1.4, Color("f58991"))
	if is_instance_valid(player):
		var point := Vector2(dungeon.world_to_cell(player.global_position))
		draw_circle(origin + point * factor, 2.5, Color("98f5d0"))
