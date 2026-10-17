extends Area2D
class_name Bullet

var data: WeaponData
var damage: float
var critical := false
var remaining_life: float = 2.5
var spent := false
var sweep_shape := CircleShape2D.new()
var elements: Dictionary = {}
var effects: Dictionary = {}
var pierces_left: int = 0
var hit_targets: Dictionary[int, bool] = {}
var excluded_bodies: Array[RID] = []

func setup(weapon_data: WeaponData, multiplier: float = 1.0, critical_chance: float = 0.0, enchantments: Dictionary = {}, pierce_count: int = 0, hit_effects: Dictionary = {}) -> void:
	data = weapon_data
	critical = randf() < critical_chance
	damage = data.damage * multiplier * (2.0 if critical else 1.0)
	remaining_life = data.projectile_lifetime
	elements = enchantments.duplicate()
	effects = hit_effects.duplicate()
	pierces_left = maxi(0, pierce_count)
	if not elements.is_empty():
		modulate = Elements.color(elements.keys()[0])

func _ready() -> void:
	add_to_group("player_projectiles")
	collision_layer = 8
	collision_mask = 5
	sweep_shape.radius = 3.0

func _physics_process(delta: float) -> void:
	if not data or spent:
		return
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()
		return
	var motion := Vector2.RIGHT.rotated(global_rotation) * maxf(data.bullet_speed, 250.0) * delta
	var space := get_world_2d().direct_space_state
	# Each pierced body is excluded from later sweeps. Continue the unused
	# part of this frame's travel so fast shots can hit several targets.
	var budget := mini(128, pierces_left + 4)
	while not spent and motion.length_squared() > 0.000001 and budget > 0:
		budget -= 1
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = sweep_shape
		query.transform = Transform2D(0.0, global_position)
		query.collision_mask = 5
		query.exclude = excluded_bodies
		var overlaps := space.intersect_shape(query)
		if not overlaps.is_empty():
			_on_body_entered(_first_body(overlaps))
			continue
		query.motion = motion
		var fractions := space.cast_motion(query)
		var fraction := fractions[1]
		global_position += motion * fraction
		query.transform.origin = global_position
		query.motion = Vector2.ZERO
		var hits := space.intersect_shape(query)
		if hits.is_empty():
			return
		_on_body_entered(_first_body(hits))
		motion *= 1.0 - fraction

func _first_body(hits: Array[Dictionary]) -> Node2D:
	# World collision takes priority if an enemy touches the same wall.
	for result in hits:
		var body := result.collider as Node2D
		if not body.has_method("take_hit"):
			return body
	return hits[0].collider as Node2D

func _on_body_entered(body: Node2D) -> void:
	if spent or not is_instance_valid(body) or hit_targets.has(body.get_instance_id()):
		return
	if body.has_method("take_hit"):
		hit_targets[body.get_instance_id()] = true
		if body is CollisionObject2D:
			excluded_bodies.append(body.get_rid())
		HitEffects.apply(body, damage, Vector2.RIGHT.rotated(global_rotation), data.knockback * 0.35, critical, elements, effects)
		if pierces_left > 0:
			pierces_left -= 1
			return
	spent = true
	queue_free()
