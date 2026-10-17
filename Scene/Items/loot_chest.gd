extends Node2D
class_name LootChest

const COST: int = 10
var target: Player
var opened := false
var locked := false
var price: int = COST
var room_id: int = -1
var pulse: float = 0.0

func _ready() -> void:
	add_to_group("chests")

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func can_open() -> bool:
	return not opened and not locked and is_instance_valid(target) and global_position.distance_to(target.global_position) < 42.0

func try_open() -> bool:
	if not can_open():
		return false
	if target.coins < price:
		EventBus.on_item_collected.emit("金币不足：宝箱需要 %d 金币" % price)
		return false
	target.coins -= price
	opened = true
	EventBus.on_inventory_updated.emit()
	queue_redraw()
	return true

func _draw() -> void:
	draw_rect(Rect2(-13, 0, 26, 4), Color(0, 0, 0, 0.25))
	var box_color := Color("71566f") if opened or locked else Color("b48162")
	draw_rect(Rect2(-13, -17, 26, 19), Color("302334"))
	draw_rect(Rect2(-11, -15, 22, 15), box_color)
	draw_rect(Rect2(-11, -13, 22, 4), Color("dab077") if not locked else Color("7f758c"))
	draw_rect(Rect2(-7, -15, 3, 15), Color("705062"))
	draw_rect(Rect2(5, -15, 3, 15), Color("705062"))
	draw_rect(Rect2(-2, -9, 5, 5), Color("f8d586") if not opened else Color("463448"))
	if not opened and not locked:
		draw_circle(Vector2(0, -23 + sin(pulse * 3.0) * 2), 2.0, Color("f8d586"))
	if can_open():
		draw_string(ThemeDB.fallback_font, Vector2(-29, -30), "E  /  FREE" if price == 0 else "E / %d G" % price, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe3a0"))
