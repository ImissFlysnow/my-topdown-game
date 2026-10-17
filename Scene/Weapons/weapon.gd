extends Node2D
class_name Weapon

@export var data: WeaponData
@onready var pivot: Node2D = $Pivot

func use_weapon() -> void:
	pass

func get_wielder() -> Player:
	return get_parent().get_parent() as Player

func can_attack() -> bool:
	var wielder := get_wielder()
	return is_instance_valid(wielder) and not wielder.health_component.is_dead and wielder.can_move

func damage_multiplier() -> float:
	return get_wielder().damage_multiplier

func cooldown_multiplier() -> float:
	return get_wielder().cooldown_multiplier * get_wielder().skills.cooldown_factor()

func is_attacking() -> bool:
	return false
