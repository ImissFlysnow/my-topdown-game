extends RefCounted
class_name Elements

enum Type { NONE, METAL, WOOD, WATER, FIRE, EARTH }
const NAMES = ["无", "金", "木", "水", "火", "土"]
const COLORS = [Color("eee9f5"), Color("ffe08a"), Color("8ae29b"), Color("80caff"), Color("ff886f"), Color("d8af84")]
# 金克木、木克土、土克水、水克火、火克金。
const COUNTERS = {Type.METAL: Type.WOOD, Type.WOOD: Type.EARTH, Type.EARTH: Type.WATER, Type.WATER: Type.FIRE, Type.FIRE: Type.METAL}

static func multiplier(attack: int, defense: int) -> float:
	if attack == Type.NONE or defense == Type.NONE:
		return 1.0
	if COUNTERS.get(attack, -1) == defense:
		return 1.5
	if COUNTERS.get(defense, -1) == attack:
		return 0.65
	return 1.0

static func color(element: int) -> Color:
	return COLORS[clampi(element, 0, 5)]

static func title(element: int) -> String:
	return NAMES[clampi(element, 0, 5)]

static func relation(attack: int, defense: int) -> String:
	var factor := multiplier(attack, defense)
	return "克" if factor > 1.0 else ("弱" if factor < 1.0 else "")
