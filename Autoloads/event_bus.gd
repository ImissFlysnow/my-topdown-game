extends Node

signal on_player_health_updated(current:float,max:float)
signal on_player_died
signal on_enemy_killed(enemy_position: Vector2, experience: int, coins: int)
signal on_inventory_updated
signal on_item_collected(item_name: String)
