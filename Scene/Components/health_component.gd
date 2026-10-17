extends Node2D
class_name HealthComponent

signal on_unit_damaged(amount: float)
signal on_unit_healed(amount: float)
signal on_unit_dead

var current_health: float
var max_health: float
var is_dead: bool = false

func init_health(value: float) -> void:
	max_health = maxf(value, 1.0)
	current_health = max_health
	is_dead = false

func take_damage(value: float) -> void:
	if is_dead or value <= 0.0:
		return
	current_health = maxf(0.0, current_health - value)
	on_unit_damaged.emit(value)
	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	on_unit_dead.emit()

func heal(value: float) -> void:
	if is_dead or value <= 0.0:
		return
	var amount := minf(value, max_health - current_health)
	if amount > 0.0:
		current_health += amount
		on_unit_healed.emit(amount)
