extends Resource
class_name EnemyData

@export var enemy_name: String = "史莱姆"
@export var texture: Texture2D
@export var max_health: float = 3.0
@export var move_speed: float = 65.0
@export var contact_damage: float = 1.0
@export var experience: int = 3
@export var coins: int = 1
@export var size_scale: float = 1.0
@export var knockback_resistance: float = 1.0
@export var tint: Color = Color.WHITE
@export_range(0, 5) var element: int = 0
@export var elite: bool = false
