extends Resource
class_name  WeaponData

@export var weapon_name:String
@export var icon:Texture2D
@export var damage:float
@export var cooldown:float
@export var mana_cost: float
@export var spread: float
@export var bullet_speed:float = 300.0
@export var bullet_scene:PackedScene
@export_multiline var description:String

@export_group("Melee")
@export_range(16.0, 160.0) var melee_range: float = 52.0
@export_range(30.0, 360.0) var melee_arc: float = 120.0
@export_range(0.05, 0.5) var attack_duration: float = 0.11
@export var knockback: float = 115.0
@export_group("Projectile")
@export_range(1, 12) var projectile_count: int = 1
@export var projectile_lifetime: float = 2.5
