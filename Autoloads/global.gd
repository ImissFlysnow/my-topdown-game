extends Node

var save_path = "user://save.json"


var settings:Dictionary = {
	"music":true,
	"sfx":true,
	"fullscreen":true
}

var all_players:Dictionary[String,PackedScene] = {
	"Bunny":preload("uid://dkm6wlfatv04a"),
	"Dog":preload("uid://blp5xv0qa7v58"),
	"Mouse":preload("uid://ynvrigrbr43a"),
	"Cat":preload("uid://yyba842j6nyj")
	
}

var all_weapons:Dictionary[String,PackedScene] = {
	"AK47":preload("uid://b5q7vdui6jjxh"),
	"AWM":preload("uid://xttqko3sjppn"),
	"MP7":preload("uid://r3qu68piswq"),
	"M4":preload("uid://e4l8msp3u5qt"),
	"Pistol":preload("uid://cubqhjuqgpfkh"),
	"Uzi":preload("uid://ccddgmxr04tdi"),
	"XM1014":preload("uid://04fgbrp5byyt"),
	"Sword":preload("uid://k6mvm4r4mgfs"),
	"Axe":preload("uid://c0s11mhoagwre")
	}

var selected_player: PlayerData
var selected_weapon:WeaponData
var skill_loadouts: Dictionary = {}

func get_skill_loadout(character: String) -> Dictionary:
	var result: Dictionary = skill_loadouts.get(character, {})
	if not SkillCatalog.valid(result.get("active", ""), character, "active"):
		result["active"] = SkillCatalog.choices(character, "active")[0].id
	if not SkillCatalog.valid(result.get("passive", ""), character, "passive"):
		result["passive"] = SkillCatalog.choices(character, "passive")[0].id
	skill_loadouts[character] = result
	return result

func _ready() -> void:
	load_data()

func get_player() -> PackedScene:
	return all_players[selected_player.id]

func get_weapon() -> PackedScene:
	return all_weapons[selected_weapon.weapon_name]

func save_date() -> void:
	var save = settings.duplicate()
	
	var file = FileAccess.open(save_path,FileAccess.WRITE)
	var json_string = JSON.stringify(save)
	file.store_string(json_string)
	file.close()
	
func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
		
	var file = FileAccess.open(save_path,FileAccess.READ)
	var json = file.get_as_text()
	var data = JSON.parse_string(json)
	file.close()
	
	settings = data
