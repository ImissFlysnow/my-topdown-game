extends Control
class_name  CharacterSelection

const PLAYER_CARD_SCENE = preload("uid://bvlgf6yv13eru")
const WEAPON_CARD_SCENE = preload("uid://66npmb374d6c")


@export var selection_cursor:Texture2D
@export var players:Array[PlayerData]
@export var weapons:Array[WeaponData]

@onready var player_container: HBoxContainer = $PlayerContainer
@onready var weapon_container: HBoxContainer = $WeaponContainer
@onready var ui_sound: AudioStreamPlayer = $UISound
@onready var hover_sound: AudioStreamPlayer = $HoverSound
var skill_tree: SkillTree
var skill_summary: Label

func  _ready() -> void:
	Cursor.sprite.texture = selection_cursor
	load_selection_items()
	_build_skill_entry()

func _build_skill_entry() -> void:
	var button := Button.new()
	button.text = "技能树 / 随机搭配"
	PixelFonts.apply(button, 12)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = SkillTree.IDLE if state == "normal" else SkillTree.SELECTED
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_texture_margin(side, 6)
		button.add_theme_stylebox_override(state, style)
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	button.offset_left = -85
	button.offset_right = 85
	button.offset_top = -103
	button.offset_bottom = -77
	button.pressed.connect(open_skill_tree)
	skill_summary = Label.new()
	add_child(skill_summary)
	skill_summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skill_summary.offset_left = -225
	skill_summary.offset_right = -35
	skill_summary.offset_top = -71
	skill_summary.offset_bottom = -21
	PixelFonts.apply(skill_summary, 10)
	_update_skill_summary()

func _update_skill_summary() -> void:
	if not is_instance_valid(skill_summary):
		return
	if not Global.selected_player:
		skill_summary.text = "选择角色后可配置技能树"
		return
	var loadout := Global.get_skill_loadout(Global.selected_player.id)
	skill_summary.text = "Q 主动：%s\n被动：%s" % [SkillCatalog.find(loadout.active).name, SkillCatalog.find(loadout.passive).name]

func open_skill_tree() -> void:
	if not Global.selected_player:
		Global.selected_player = players[0]
		for card: PlayerCard in player_container.get_children():
			card.selector.visible = card.data == Global.selected_player
	if is_instance_valid(skill_tree):
		remove_child(skill_tree)
		skill_tree.queue_free()
	var loadout := Global.get_skill_loadout(Global.selected_player.id)
	skill_tree = SkillTree.new()
	skill_tree.character = Global.selected_player
	skill_tree.active_id = loadout.active
	skill_tree.passive_id = loadout.passive
	skill_tree.confirmed.connect(_update_skill_summary)
	skill_tree.visibility_changed.connect(_update_skill_summary)
	add_child(skill_tree)

func load_selection_items() -> void:
	for node in player_container.get_children():
		node.queue_free()
	for node in weapon_container.get_children():
		node.queue_free()
	
	
	for data: PlayerData in players:
		var card: PlayerCard = PLAYER_CARD_SCENE.instantiate()
		card.pressed.connect(_on_play_card_pressed.bind(data,card))
		player_container.add_child(card)
		card.set_data(data)
		card.selector.visible = data == Global.selected_player

	for data: WeaponData in weapons:
		var card: WeaponCard = WEAPON_CARD_SCENE.instantiate()
		card.pressed.connect(_on_weapon_card_pressed.bind(data,card))
		weapon_container.add_child(card)
		card.set_data(data)
		card.selector.visible = data == Global.selected_weapon


func _on_play_button_pressed() -> void:
	if not Global.selected_player or not Global.selected_weapon:
		return
		
		
	ui_sound.play()
	Transition.transition_to("res://Scene/Arena/arena.tscn")


func _on_back_button_pressed() -> void:
	ui_sound.play()
	Transition.transition_to("res://Scene/ui/main_menu.tscn")


func _on_play_card_pressed(data:PlayerData,selected_card:PlayerCard) ->void:
	ui_sound.play()
	Global.selected_player = data 
	_update_skill_summary()
	for card:PlayerCard in player_container.get_children():
		card.selector.hide()
	selected_card.selector.show()

func _on_weapon_card_pressed(data:WeaponData,selected_card:WeaponCard) ->void:
	ui_sound.play()
	Global.selected_weapon = data 
	for card:WeaponCard in weapon_container.get_children():
		card.selector.hide()
	selected_card.selector.show()


func _on_play_button_mouse_entered() -> void:
	hover_sound.play()


func _on_back_button_mouse_entered() -> void:
	hover_sound.play()
