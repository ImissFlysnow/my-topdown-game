extends Resource
class_name ItemData

enum Kind { EXPERIENCE, COIN, HEAL, DAMAGE, SPEED, ATTACK_SPEED, MAGNET, LIGHT_GRIP, ARMOR_PIERCING, HEADHUNTER, FROST_SHARD, EMBER_MARK, GREEDY_POUCH,
	ECHO_CAPACITOR, ENERGY_MEDAL, CAST_GAUNTLET, WIND_BOOTS, ENERGY_CRYSTAL, HASTE_SIGIL, SPEED_RIBBON, RESIDUAL_CHARM, COMBO_RING, TALENT_BADGE, EMERGENCY_BATTERY }
@export var item_name: String
@export var kind: Kind = Kind.EXPERIENCE
@export var icon: Texture2D
@export var amount: float = 1.0
@export var tint: Color = Color.WHITE
@export var rarity: int = -1
@export var proportional: bool = false
@export var requires_ranged: bool = false
@export var shop_price: int = 8
@export var max_stacks: int = 0
@export_multiline var description: String
