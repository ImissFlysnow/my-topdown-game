extends RefCounted
class_name SkillCatalog

const DEFINITIONS = preload("res://Data/Skills/skill_definitions.gd")
const TITLES = {"Bunny": "兔子 · 灵动游侠", "Cat": "猫咪 · 暗影猎手", "Dog": "小狗 · 坚毅守卫", "Mouse": "老鼠 · 元素巧匠"}

static func choices(character: String, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS.ENTRIES:
		if entry.character == character and entry.kind == kind:
			result.append(entry)
	return result

static func find(id: String) -> Dictionary:
	for entry: Dictionary in DEFINITIONS.ENTRIES:
		if entry.id == id:
			return entry
	return {}

static func valid(id: String, character: String, kind: String) -> bool:
	var entry := find(id)
	return not entry.is_empty() and entry.character == character and entry.kind == kind

static func icon(id: String) -> Texture2D:
	return load("res://Assets/Skills/%s.png" % id) as Texture2D
