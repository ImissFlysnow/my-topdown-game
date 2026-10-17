extends Node

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	run.call_deferred()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var music_id := Music.get_instance_id()
	# This runner survives current-scene changes.
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scene/ui/main_menu.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().current_scene is MainMenu, "project opens its existing main menu")
	check(Music.playing, "background music plays in main menu")
	get_tree().current_scene._on_play_button_pressed()
	await get_tree().create_timer(2.2).timeout
	var selection := get_tree().current_scene as CharacterSelection
	check(is_instance_valid(selection), "main menu transitions to selection")
	check(Music.playing and Music.get_instance_id() == music_id, "background music continues in character selection")
	check(selection.player_container.get_child_count() == 4 and selection.weapon_container.get_child_count() == 9, "selection shows four characters and nine weapons")
	selection.player_container.get_child(2).pressed.emit()
	selection.weapon_container.get_child(8).pressed.emit()
	var selected_id := Global.selected_player.id
	check(Global.selected_weapon.weapon_name == "Axe", "selection card equips axe data")
	selection.open_skill_tree()
	check(selection.skill_tree.buttons.size() == 6, "selection opens the chosen character's six skill nodes")
	selection.skill_tree.buttons["dog_shield"].pressed.emit()
	selection.skill_tree.buttons["dog_hide"].pressed.emit()
	selection.skill_tree.confirmed.emit()
	selection.skill_tree.hide()
	check(Global.get_skill_loadout(selected_id).active == "dog_shield" and Global.get_skill_loadout(selected_id).passive == "dog_hide", "actual skill node clicks save independent active and passive choices")
	selection._on_play_button_pressed()
	await get_tree().create_timer(2.2).timeout
	var arena := get_tree().current_scene as Arena
	check(is_instance_valid(arena), "selection transitions to dungeon")
	check(arena.player.data.id == selected_id and arena.player.weapon_controller.current_weapon is WeaponMelee, "selected player and melee weapon are loaded")
	check(arena.player.skills.active_id == "dog_shield" and arena.player.skills.passive_id == "dog_hide", "starting a run equips the chosen skill loadout")
	check(Music.playing and Music.get_instance_id() == music_id, "background music continues in first run")
	var weapon := arena.player.weapon_controller.current_weapon as WeaponMelee
	var nearby_enemy := Arena.ENEMY_SCENE.instantiate() as Enemy
	nearby_enemy.data = Arena.ENEMIES[0]
	nearby_enemy.position = arena.player.position + Vector2(30, 0)
	nearby_enemy.target = arena.player
	nearby_enemy.dungeon = arena.dungeon
	arena.actors.add_child(nearby_enemy)
	nearby_enemy.set_physics_process(false)
	await get_tree().create_timer(0.25).timeout
	check(nearby_enemy.health_component.current_health == nearby_enemy.health_component.max_health, "nearby enemy does not trigger an attack without mouse input")
	var aim_direction := Vector2.RIGHT.rotated(weapon.pivot.global_rotation)
	var mouse_direction := weapon.pivot.global_position.direction_to(weapon.get_global_mouse_position())
	check(aim_direction.dot(mouse_direction) > 0.99, "weapon aims at mouse instead of nearest enemy")
	Input.action_press("shoot")
	await get_tree().create_timer(0.1).timeout
	check(not weapon.can_use, "holding left mouse attacks")
	Input.action_release("shoot")
	await get_tree().create_timer(0.35).timeout
	check(weapon.can_use, "releasing left mouse stops attacking")
	nearby_enemy.queue_free()
	key(KEY_TAB, true)
	key(KEY_TAB, false)
	await get_tree().process_frame
	check(arena.hud.inventory_label.visible, "Tab opens inventory through actual input")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await get_tree().process_frame
	check(get_tree().paused and arena.hud.modal.visible, "Escape opens pause menu")
	check(Cursor.can_process(), "custom cursor continues updating while paused")
	var position := arena.player.position
	Input.action_press("move_right")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("move_right")
	check(arena.player.position == position, "pause stops player movement")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await get_tree().process_frame
	check(not get_tree().paused and not arena.hud.modal.visible, "Escape resumes game")
	Input.action_press("move_right")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("move_right")
	check(arena.player.position.x > position.x + 10, "WASD movement works after resuming")
	var chest := get_tree().get_first_node_in_group("chests") as LootChest
	arena.player.position = chest.position
	arena.player.coins = 10
	key(KEY_E, true)
	key(KEY_E, false)
	await get_tree().process_frame
	check(not chest.opened and arena.player.coins == 10, "E cannot open a locked challenge chest")
	var hp := arena.player.health_component.current_health
	# Space must no longer be the prototype's self-damage shortcut.
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await get_tree().process_frame
	check(arena.player.health_component.current_health == hp, "space no longer damages the player")
	arena.player.invulnerability = 0
	arena.player.take_hit(999)
	await get_tree().process_frame
	await get_tree().process_frame
	check(arena.hud.modal.visible and get_tree().paused, "death opens usable result screen")
	check(Music.playing, "background music continues on result screen")
	var modal_buttons := arena.hud.modal.get_child(0).get_children()
	for button in modal_buttons:
		if button is Button and button.text.begins_with("再来"):
			button.pressed.emit()
			break
	await get_tree().process_frame
	await get_tree().process_frame
	arena = get_tree().current_scene as Arena
	check(is_instance_valid(arena) and not get_tree().paused, "result button restarts the run")
	check(get_tree().get_nodes_in_group("player").size() == 1, "restart leaves exactly one player")
	check(arena.player.level == 1 and arena.player.coins == 0 and arena.player.damage_multiplier == 1.0, "restart resets run stats")
	check(Global.selected_player.id == selected_id and Global.selected_weapon.weapon_name == "Axe", "restart keeps chosen character and weapon")
	check(arena.player.skills.active_id == "dog_shield" and arena.player.skills.passive_id == "dog_hide", "restart keeps the chosen skills and resets temporary skill state")
	check(Music.playing and Music.get_instance_id() == music_id, "restarting keeps background music playing")
	Music.play(Music.stream.get_length() - 0.1)
	arena.return_to_selection()
	await get_tree().create_timer(2.2).timeout
	selection = get_tree().current_scene as CharacterSelection
	check(is_instance_valid(selection), "result flow returns to character selection")
	check(selection.player_container.get_child(2).selector.visible and selection.weapon_container.get_child(8).selector.visible, "returning selection restores chosen card highlights")
	check(Music.playing and Music.get_instance_id() == music_id, "song loops while returning to character selection")
	selection.player_container.get_child(0).pressed.emit()
	selection.weapon_container.get_child(7).pressed.emit()
	selection._on_play_button_pressed()
	await get_tree().create_timer(2.2).timeout
	arena = get_tree().current_scene as Arena
	check(is_instance_valid(arena) and arena.player.data.id == "Bunny", "different character can start a second run")
	check(Music.playing and Music.get_instance_id() == music_id, "background music continues after selecting another character")
	print("RESULT: %d/%d menu flow checks passed" % [checks - failures, checks])
	Music.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
