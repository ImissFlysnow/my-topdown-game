extends Node2D
class_name RoomService

enum Kind { SHOP, EVENT, EXIT }
var kind: Kind = Kind.SHOP
var target: Player
var resolved := false
var age: float = 0
const MERCHANT = preload("res://01.基础资源/Assets/Sprites/Enemies/Sprites/tile_0004.png")

func _ready() -> void:
	add_to_group("room_services")

func nearby() -> bool:
	return is_instance_valid(target) and global_position.distance_to(target.global_position) < 55

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	if kind == Kind.SHOP:
		draw_rect(Rect2(-28, -9, 56, 18), Color("493447"))
		draw_rect(Rect2(-26, -7, 52, 12), Color("b28463"))
		draw_texture_rect(MERCHANT, Rect2(-14, -40, 28, 28), false)
		draw_circle(Vector2(-15, -13), 4, Color("f8d586"))
		draw_circle(Vector2(13, -13), 4, Color("8de7b3"))
	elif kind == Kind.EVENT:
		draw_rect(Rect2(-15, -8, 30, 13), Color("56465e"))
		draw_rect(Rect2(-11, -13, 22, 7), Color("8b7898"))
		var color := Color("63586f") if resolved else Color("8bded1")
		draw_colored_polygon(PackedVector2Array([Vector2(0, -38), Vector2(11, -25), Vector2(0, -12), Vector2(-11, -25)]), color)
		if not resolved:
			draw_circle(Vector2(0, -25), 17 + sin(age * 3) * 2, Color(color, 0.13))
	else:
		draw_circle(Vector2.ZERO, 25, Color(0.4, 0.9, 0.8, 0.15))
		draw_arc(Vector2(0, -15), 23, 0, TAU, 36, Color("9af2df"), 3)
		draw_arc(Vector2(0, -15), 16 + sin(age * 4) * 2, 0, TAU, 36, Color("c0a6ef"), 2)
	if nearby():
		var text := "E / NEXT" if kind == Kind.EXIT else ("E / SHOP" if kind == Kind.SHOP else ("USED" if resolved else "E / EVENT"))
		draw_string(PixelFonts.get_font(10), Vector2(-24, -51), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffe3a0"))
