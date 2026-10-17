extends Weapon
class_name WeaponRange

@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var fire_pos: Marker2D = %FirePos
@onready var shoot_sound: AudioStreamPlayer = $Shootsound
var cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	sprite_2d.flip_v = Vector2.RIGHT.rotated(pivot.global_rotation).x < 0.0

func use_weapon() -> void:
	if cooldown > 0.0 or not can_attack() or not data.bullet_scene:
		return
	cooldown = maxf(0.04, data.cooldown * cooldown_multiplier())
	shoot_sound.play()
	var attack := get_wielder().skills.begin_attack()
	for index in data.projectile_count:
		var bullet := data.bullet_scene.instantiate() as Bullet
		bullet.setup(data, float(attack.multiplier) * get_wielder().ranged_damage_factor, attack.critical_chance, attack.elements, get_wielder().projectile_pierce, attack.effects)
		get_tree().current_scene.add_child(bullet)
		# Keep a barrel touching a wall from firing through it.
		var ray := PhysicsRayQueryParameters2D.create(global_position, fire_pos.global_position, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		bullet.global_position = fire_pos.global_position if wall.is_empty() else global_position
		var spread := randf_range(-data.spread, data.spread)
		if data.projectile_count > 1:
			spread += lerpf(-12.0, 12.0, float(index) / float(data.projectile_count - 1))
		bullet.global_rotation = pivot.global_rotation + deg_to_rad(spread)
