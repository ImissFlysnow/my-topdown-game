extends RefCounted
class_name ItemLoot

const TIERS = [0.05, 0.10, 0.15, 0.25]
const WEIGHTS = [50, 31, 16, 3]
const TIER_NAMES = ["普通", "优良", "稀有", "史诗"]
const TIER_COLORS = [Color("ddd8e8"), Color("8ae29b"), Color("80caff"), Color("d1a2ff")]
const POTIONS: Array[ItemData] = [preload("res://Data/Items/damage.tres"), preload("res://Data/Items/speed.tres"), preload("res://Data/Items/attack_speed.tres"), preload("res://Data/Items/magnet.tres")]
const POTION_NAMES = ["力量药水", "疾行药水", "迅捷药水", "引力药水"]
const STAT_NAMES = ["伤害", "移动速度", "攻击速度", "拾取范围"]
const HEALING_POTIONS: Array[ItemData] = [preload("res://Data/Items/health_potion_small.tres"), preload("res://Data/Items/health_potion_medium.tres"), preload("res://Data/Items/health_potion_large.tres")]
const SHOP_PERKS: Array[ItemData] = [preload("res://Data/Items/light_grip.tres"), preload("res://Data/Items/armor_piercing.tres"), preload("res://Data/Items/headhunter.tres"), preload("res://Data/Items/frost_shard.tres"), preload("res://Data/Items/ember_mark.tres"), preload("res://Data/Items/greedy_pouch.tres")]
const SKILL_PERKS: Array[ItemData] = [preload("res://Data/Items/echo_capacitor.tres"), preload("res://Data/Items/energy_medal.tres"), preload("res://Data/Items/cast_gauntlet.tres"), preload("res://Data/Items/wind_boots.tres"), preload("res://Data/Items/energy_crystal.tres"), preload("res://Data/Items/haste_sigil.tres"), preload("res://Data/Items/speed_ribbon.tres"), preload("res://Data/Items/residual_charm.tres"), preload("res://Data/Items/combo_ring.tres"), preload("res://Data/Items/talent_badge.tres"), preload("res://Data/Items/emergency_battery.tres")]

static func tier_for_roll(roll: int) -> int:
	var cumulative := 0
	for tier in WEIGHTS.size():
		cumulative += WEIGHTS[tier]
		if clampi(roll, 0, 99) < cumulative:
			return tier
	return 3

static func make_potion(kind_index: int, tier: int) -> ItemData:
	kind_index = clampi(kind_index, 0, POTIONS.size() - 1)
	tier = clampi(tier, 0, TIERS.size() - 1)
	var item := POTIONS[kind_index].duplicate() as ItemData
	item.amount = TIERS[tier]
	item.rarity = tier
	item.proportional = true
	item.tint = TIER_COLORS[tier]
	item.item_name = "%s·%s +%d%%" % [TIER_NAMES[tier], POTION_NAMES[kind_index], roundi(item.amount * 100)]
	item.description = "%s提升 %d%%（永久）" % [STAT_NAMES[kind_index], roundi(item.amount * 100)]
	# All chest rewards remain stat potions, never healing consumables.
	item.icon = POTIONS[0 if kind_index % 2 == 0 else 2].icon
	return item

static func roll_potion(rng: RandomNumberGenerator) -> ItemData:
	var tier := tier_for_roll(rng.randi_range(0, 99))
	return make_potion(rng.randi_range(0, POTIONS.size() - 1), tier)
