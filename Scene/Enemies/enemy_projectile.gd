extends Node2D
class_name EnemyProjectile

var target: Player
var direction := Vector2.RIGHT
var speed: float = 110
var damage: float = 2
var element: int = Elements.Type.FIRE
var lifetime: float = 3.0
var age: float = 0
var homing_turn_rate: float = 0
var homing_duration: float = 1.4
var curve_rate: float = 0

func _ready() -> void:
	add_to_group("enemy_attacks")
	z_index = 2

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	if homing_turn_rate > 0 and age < homing_duration and is_instance_valid(target):
		var desired := global_position.direction_to(target.global_position + Vector2(0, -7))
		var angle := direction.angle_to(desired)
		direction = direction.rotated(clampf(angle, -homing_turn_rate * delta, homing_turn_rate * delta)).normalized()
	if curve_rate != 0:
		direction = direction.rotated(curve_rate * delta)
	var skill_speed_factor := 1.0
	for effect in get_tree().get_nodes_in_group("player_skill_effects"):
		skill_speed_factor = minf(skill_speed_factor, effect.projectile_speed_factor(global_position))
	var destination := global_position + direction * speed * skill_speed_factor * delta
	var ray := PhysicsRayQueryParameters2D.create(global_position, destination, 3)
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var body: Node2D = hit.collider
		if body == target:
			target.take_hit(damage, direction, 75, false, element)
		queue_free()
		return
	global_position = destination

func _draw() -> void:
	var radius := 4.5 if homing_turn_rate > 0 else 3.0
	draw_circle(Vector2.ZERO, radius + 3, Color(Elements.color(element), 0.18))
	draw_circle(Vector2.ZERO, radius, Elements.color(element))
	draw_circle(Vector2(-1, -1), 1, Color.WHITE)
