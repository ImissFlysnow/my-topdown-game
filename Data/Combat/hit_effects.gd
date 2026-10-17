extends RefCounted
class_name HitEffects

static func apply(body: Node2D, amount: float, direction: Vector2, force: float, critical: bool, enchantments: Dictionary, effects: Dictionary = {}) -> bool:
	if not is_instance_valid(body) or not body.has_method("take_hit"):
		return false
	var source: Player
	if effects.has("source_player"):
		source = effects.source_player.get_ref() as Player
	if body is Enemy and is_instance_valid(source):
		amount *= source.skills.hit_bonus(body, effects)
	var pure_element := int(effects.get("pure_element", Elements.Type.NONE))
	if body is Enemy and pure_element != Elements.Type.NONE:
		# Enemy's -1 key changes the physical component into a colored elemental
		# component while preserving Boss shields, phases and damage accounting.
		enchantments = {pure_element: 1.0, -1: 1.0}
	if body is Enemy and (body.data.elite or body.is_in_group("bosses")):
		amount *= 1.0 + float(effects.get("hunter_bonus", 0.0))
	var before: float = body.health_component.current_health + (body.shield_value() if body.has_method("shield_value") else 0.0) if body is Enemy else 0.0
	var accepted: bool = body.take_hit(amount, direction, force, critical, enchantments)
	var after: float = body.health_component.current_health + (body.shield_value() if body.has_method("shield_value") else 0.0) if body is Enemy else 0.0
	if accepted and before > after and body is Enemy and is_instance_valid(source):
		source.skills.after_hit(body, effects)
	if not accepted or not is_instance_valid(body) or not body is Enemy or not body.can_receive_status_effects():
		return accepted
	if randf() < float(effects.get("frost_chance", 0.0)):
		body.apply_slow(1.5, 0.75)
	if randf() < float(effects.get("burn_chance", 0.0)):
		body.apply_burn(amount * 0.60 * (source.skills.elemental_factor() if is_instance_valid(source) else 1.0))
	return accepted
