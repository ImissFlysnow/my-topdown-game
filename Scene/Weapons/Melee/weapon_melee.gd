extends Weapon
class_name WeaponMelee

@onready var sprite_2d: Sprite2D = %Sprite2D
@onready var slash: GPUParticles2D = %SlashParticle
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var slash_sound: AudioStreamPlayer = $SlashSound
@onready var cooldown: Timer = $Cooldown
@onready var hitbox: Area2D = $Pivot/Hitbox

var can_use := true
var attack_time: float = 0.0
var swing_duration: float = 0.11
var hit_targets: Dictionary[int, bool] = {}
var query_shape := CircleShape2D.new()
var attack_snapshot: Dictionary = {}

func _ready() -> void:
	cooldown.one_shot = true
	cooldown.timeout.connect(_on_cooldown_timeout)
	query_shape.radius = data.melee_range
	$Pivot/Hitbox/CollisionShape2D.shape = query_shape
	$Pivot/Hitbox/CollisionShape2D.position = Vector2.ZERO
	hitbox.monitoring = false
	anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if attack_time <= 0.0:
		return
	if not can_attack():
		attack_time = 0.0
		hitbox.monitoring = false
		queue_redraw()
		return
	_check_hits()
	attack_time = maxf(0.0, attack_time - delta)
	if attack_time <= 0.0:
		hitbox.monitoring = false
	queue_redraw()

func use_weapon() -> void:
	if not can_use or not can_attack():
		return
	can_use = false
	attack_snapshot = get_wielder().skills.begin_attack()
	hit_targets.clear()
	swing_duration = maxf(0.02, data.attack_duration * cooldown_multiplier())
	attack_time = swing_duration
	cooldown.start(maxf(swing_duration + 0.01, data.cooldown * cooldown_multiplier()))
	hitbox.monitoring = true
	slash_sound.pitch_scale = randf_range(0.94, 1.06)
	slash_sound.play()
	anim_player.speed_scale = 0.1 / swing_duration
	anim_player.play("slash")
	slash.global_rotation = pivot.global_rotation
	slash.restart()
	_check_hits()
	queue_redraw()

func _check_hits() -> void:
	# Query throughout the active swing, including enemies already overlapping.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4
	var facing := Vector2.RIGHT.rotated(pivot.global_rotation)
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var body := result.collider as Node2D
		if not is_instance_valid(body) or not body.has_method("take_hit"):
			continue
		var id := body.get_instance_id()
		if hit_targets.has(id):
			continue
		var point := body.global_position + Vector2(0, -7)
		var offset := point - global_position
		if absf(facing.angle_to(offset)) > deg_to_rad(data.melee_arc * 0.5):
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, point, 1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		hit_targets[id] = true
		var critical := randf() < float(attack_snapshot.critical_chance)
		HitEffects.apply(body, data.damage * float(attack_snapshot.multiplier) * (2.0 if critical else 1.0), offset.normalized(), data.knockback, critical, attack_snapshot.elements, attack_snapshot.effects)

func _draw() -> void:
	if attack_time <= 0.0:
		return
	var half_arc := deg_to_rad(data.melee_arc * 0.5)
	var angle := pivot.rotation
	var opacity := attack_time / swing_duration
	var color := Elements.color(get_wielder().weapon_elements.keys()[0]) if not get_wielder().weapon_elements.is_empty() else Color(0.85, 0.95, 1.0)
	draw_arc(Vector2.ZERO, data.melee_range - 4.0, angle - half_arc, angle + half_arc, 28, Color(color, opacity * 0.8), 3.0, true)
	draw_arc(Vector2.ZERO, data.melee_range - 12.0, angle - half_arc, angle + half_arc, 28, Color(0.6, 0.85, 1.0, opacity * 0.25), 7.0, true)

func is_attacking() -> bool:
	return attack_time > 0.0

func _on_cooldown_timeout() -> void:
	can_use = true
	anim_player.speed_scale = 1.0
	anim_player.play("idle")
