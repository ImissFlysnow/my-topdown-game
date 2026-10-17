extends Node2D
class_name WeaponController

var current_weapon: Weapon
var target_pos: Vector2

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(current_weapon) or not current_weapon.can_attack():
		return
	target_pos = get_global_mouse_position()
	if not current_weapon.is_attacking():
		current_weapon.pivot.look_at(target_pos)
	if Input.is_action_pressed("shoot"):
		current_weapon.use_weapon()

func equip_weapon() -> void:
	if is_instance_valid(current_weapon):
		remove_child(current_weapon)
		current_weapon.queue_free()
	current_weapon = Global.get_weapon().instantiate() as Weapon
	current_weapon.data = Global.selected_weapon
	current_weapon.position = Vector2(0, -7)
	add_child(current_weapon)
