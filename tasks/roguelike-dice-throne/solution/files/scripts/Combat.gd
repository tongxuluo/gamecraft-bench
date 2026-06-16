extends Control

var main: Node = null
var fight_index: int = 0

# Combat state
var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_dice_count: int = 0
var enemy_faces: Array = []

var player_dice_results: Array = []  # current face for each die
var player_locked: Array = []  # bool per die
var rerolls_left: int = 2

var enemy_dice_results: Array = []
var turn_phase: String = "rolling"  # rolling, resolving, enemy_turn, done

# UI refs
var dice_rects: Array = []
var dice_labels: Array = []
var lock_indicators: Array = []
var reroll_btn: Button = null
var end_turn_btn: Button = null
var player_hp_label: Label = null
var enemy_hp_label: Label = null
var status_label: Label = null
var enemy_dice_rects: Array = []
var enemy_dice_labels: Array = []

# RNG
var rng: RandomNumberGenerator = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	rng = RandomNumberGenerator.new()
	rng.seed = 12345 + fight_index * 1000
	_setup_enemy()
	_build_ui()
	_roll_all_dice()

func _setup_enemy() -> void:
	if fight_index == 0:
		enemy_name = "Goblin"
		enemy_hp = 25
		enemy_max_hp = 25
		enemy_dice_count = 3
		enemy_faces = ["sword", "sword", "shield", "blank", "blank", "blank"]
	elif fight_index == 1:
		enemy_name = "Skeleton"
		enemy_hp = 35
		enemy_max_hp = 35
		enemy_dice_count = 4
		enemy_faces = ["sword", "sword", "skull", "shield", "blank", "blank"]
	elif fight_index == 2:
		enemy_name = "Dark Knight"
		enemy_hp = 45
		enemy_max_hp = 45
		enemy_dice_count = 4
		enemy_faces = ["sword", "sword", "sword", "shield", "shield", "skull"]
	else:
		enemy_name = "DRAGON LORD"
		enemy_hp = 60
		enemy_max_hp = 60
		enemy_dice_count = 5
		enemy_faces = ["sword", "sword", "skull", "skull", "shield", "heart"]

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.12)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Fight info
	var fight_label = Label.new()
	var fight_text = "Fight %d/4" % (fight_index + 1)
	if fight_index == 3:
		fight_text = "BOSS FIGHT"
	fight_label.text = fight_text
	fight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fight_label.add_theme_font_size_override("font_size", 20)
	fight_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	fight_label.position = Vector2(540, 10)
	fight_label.size = Vector2(200, 30)
	add_child(fight_label)

	# Enemy section (top)
	var enemy_title = Label.new()
	enemy_title.text = enemy_name
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_title.add_theme_font_size_override("font_size", 28)
	enemy_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	enemy_title.position = Vector2(490, 45)
	enemy_title.size = Vector2(300, 40)
	add_child(enemy_title)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_hp_label.add_theme_font_size_override("font_size", 20)
	enemy_hp_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	enemy_hp_label.position = Vector2(540, 85)
	enemy_hp_label.size = Vector2(200, 30)
	add_child(enemy_hp_label)

	# Enemy dice
	for i in range(enemy_dice_count):
		var r = ColorRect.new()
		r.color = Color(0.6, 0.2, 0.2)
		r.size = Vector2(55, 55)
		var x_off = 640 - (enemy_dice_count * 65) / 2 + i * 65
		r.position = Vector2(x_off, 120)
		add_child(r)
		enemy_dice_rects.append(r)
		var lbl = Label.new()
		lbl.text = "?"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.position = Vector2(x_off + 5, 130)
		lbl.size = Vector2(45, 40)
		add_child(lbl)
		enemy_dice_labels.append(lbl)

	# Player section (bottom)
	player_hp_label = Label.new()
	player_hp_label.text = "Your HP: %d/%d" % [main.player_hp, main.player_max_hp]
	player_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_label.add_theme_font_size_override("font_size", 22)
	player_hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	player_hp_label.position = Vector2(490, 620)
	player_hp_label.size = Vector2(300, 30)
	add_child(player_hp_label)

	# Player dice (clickable area)
	for i in range(5):
		var x_pos = 290 + i * 140
		var y_pos = 420
		var r = ColorRect.new()
		r.color = Color(0.9, 0.9, 0.95)
		r.size = Vector2(80, 80)
		r.position = Vector2(x_pos, y_pos)
		add_child(r)
		dice_rects.append(r)

		var lbl = Label.new()
		lbl.text = ""
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
		lbl.position = Vector2(x_pos + 5, 435)
		lbl.size = Vector2(70, 50)
		add_child(lbl)
		dice_labels.append(lbl)

		var lock_lbl = Label.new()
		lock_lbl.text = ""
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 14)
		lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		lock_lbl.position = Vector2(x_pos, y_pos + 82)
		lock_lbl.size = Vector2(80, 20)
		add_child(lock_lbl)
		lock_indicators.append(lock_lbl)

	# Reroll button
	reroll_btn = Button.new()
	reroll_btn.text = "REROLL (%d)" % rerolls_left
	reroll_btn.position = Vector2(350, 550)
	reroll_btn.size = Vector2(200, 50)
	reroll_btn.add_theme_font_size_override("font_size", 20)
	reroll_btn.pressed.connect(_on_reroll)
	reroll_btn.name = "RerollBtn"
	add_child(reroll_btn)

	# End turn button
	end_turn_btn = Button.new()
	end_turn_btn.text = "END TURN"
	end_turn_btn.position = Vector2(700, 550)
	end_turn_btn.size = Vector2(200, 50)
	end_turn_btn.add_theme_font_size_override("font_size", 20)
	end_turn_btn.pressed.connect(_on_end_turn)
	end_turn_btn.name = "EndTurnBtn"
	add_child(end_turn_btn)

	# Status label
	status_label = Label.new()
	status_label.text = "Click dice to lock, then Reroll or End Turn"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	status_label.position = Vector2(340, 380)
	status_label.size = Vector2(600, 25)
	add_child(status_label)

	# Rerolls left label
	var reroll_info = Label.new()
	reroll_info.text = "Click a die to LOCK/UNLOCK it"
	reroll_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll_info.add_theme_font_size_override("font_size", 14)
	reroll_info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	reroll_info.position = Vector2(390, 510)
	reroll_info.size = Vector2(500, 20)
	add_child(reroll_info)

func _face_symbol(face: String) -> String:
	match face:
		"sword": return "ATK"
		"shield": return "DEF"
		"heart": return "HEAL"
		"skull": return "SKL"
		"fire_sword": return "FIRE"
		"double_shield": return "DEF+"
		"vampiric": return "VAMP"
		_: return "--"

func _face_color(face: String) -> Color:
	match face:
		"sword": return Color(0.8, 0.2, 0.2)
		"shield": return Color(0.2, 0.4, 0.9)
		"heart": return Color(0.2, 0.8, 0.3)
		"skull": return Color(0.6, 0.1, 0.6)
		"fire_sword": return Color(1.0, 0.4, 0.0)
		"double_shield": return Color(0.3, 0.5, 1.0)
		"vampiric": return Color(0.5, 0.0, 0.3)
		_: return Color(0.5, 0.5, 0.5)

func _roll_single_die(die_index: int) -> String:
	var faces = main.dice_faces[die_index]
	var idx = rng.randi_range(0, faces.size() - 1)
	return faces[idx]

func _roll_all_dice() -> void:
	player_dice_results.clear()
	player_locked.clear()
	for i in range(5):
		player_dice_results.append(_roll_single_die(i))
		player_locked.append(false)
	rerolls_left = 2
	turn_phase = "rolling"
	_update_dice_display()
	_update_buttons()

func _update_dice_display() -> void:
	for i in range(5):
		var face = player_dice_results[i]
		dice_labels[i].text = _face_symbol(face)
		dice_labels[i].remove_theme_color_override("font_color")
		dice_labels[i].add_theme_color_override("font_color", _face_color(face))
		if player_locked[i]:
			dice_rects[i].color = Color(1.0, 1.0, 0.7)
			lock_indicators[i].text = "LOCKED"
		else:
			dice_rects[i].color = Color(0.9, 0.9, 0.95)
			lock_indicators[i].text = ""

func _update_buttons() -> void:
	if reroll_btn:
		reroll_btn.text = "REROLL (%d)" % rerolls_left
		reroll_btn.disabled = rerolls_left <= 0 or turn_phase != "rolling"
	if end_turn_btn:
		end_turn_btn.disabled = turn_phase != "rolling"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if turn_phase != "rolling":
			return
		var click_pos = event.position
		for i in range(5):
			var x_pos = 290 + i * 140
			var y_pos = 420
			var rect = Rect2(Vector2(x_pos, y_pos), Vector2(80, 80))
			if rect.has_point(click_pos):
				player_locked[i] = not player_locked[i]
				_update_dice_display()
				break

func _on_reroll() -> void:
	if rerolls_left <= 0 or turn_phase != "rolling":
		return
	rerolls_left -= 1
	for i in range(5):
		if not player_locked[i]:
			player_dice_results[i] = _roll_single_die(i)
	_update_dice_display()
	_update_buttons()

func _on_end_turn() -> void:
	if turn_phase != "rolling":
		return
	turn_phase = "resolving"
	_resolve_player_turn()
	_resolve_enemy_turn()
	_check_combat_end()

func _resolve_player_turn() -> void:
	var damage = 0
	var block = 0
	var heal = 0
	var special = 0
	for face in player_dice_results:
		match face:
			"sword": damage += 5
			"shield": block += 4
			"heart": heal += 6
			"skull": special += 8
			"fire_sword": damage += 10
			"double_shield": block += 8
			"vampiric":
				damage += 4
				heal += 3
	# Apply player damage to enemy
	var total_attack = damage + special
	enemy_hp -= total_attack
	if enemy_hp < 0:
		enemy_hp = 0
	# Heal player
	main.player_hp = mini(main.player_hp + heal, main.player_max_hp)
	# Store block for defense
	_stored_block = block
	status_label.text = "You deal %d dmg, block %d, heal %d" % [total_attack, block, heal]
	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	player_hp_label.text = "Your HP: %d/%d" % [main.player_hp, main.player_max_hp]

var _stored_block: int = 0

func _resolve_enemy_turn() -> void:
	enemy_dice_results.clear()
	var enemy_damage = 0
	var enemy_block = 0
	var enemy_heal = 0
	for i in range(enemy_dice_count):
		var idx = rng.randi_range(0, enemy_faces.size() - 1)
		var face = enemy_faces[idx]
		enemy_dice_results.append(face)
		match face:
			"sword": enemy_damage += 5
			"shield": enemy_block += 3
			"heart": enemy_heal += 5
			"skull": enemy_damage += 7
	# Show enemy dice
	for i in range(enemy_dice_count):
		enemy_dice_labels[i].text = _face_symbol(enemy_dice_results[i])
	# Apply enemy damage minus player block
	var net_damage = maxi(0, enemy_damage - _stored_block)
	main.player_hp -= net_damage
	if main.player_hp < 0:
		main.player_hp = 0
	# Enemy heals
	enemy_hp = mini(enemy_hp + enemy_heal, enemy_max_hp)
	player_hp_label.text = "Your HP: %d/%d" % [main.player_hp, main.player_max_hp]
	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_max_hp]
	var msg = status_label.text + " | Enemy deals %d (-%d block)" % [enemy_damage, _stored_block]
	status_label.text = msg

func _check_combat_end() -> void:
	if enemy_hp <= 0:
		status_label.text = "VICTORY! " + enemy_name + " defeated!"
		_end_combat(true)
	elif main.player_hp <= 0:
		status_label.text = "DEFEATED! You have fallen..."
		_end_combat(false)
	else:
		# Next turn
		turn_phase = "rolling"
		_start_new_turn()

func _start_new_turn() -> void:
	for i in range(5):
		player_dice_results[i] = _roll_single_die(i)
		player_locked[i] = false
	rerolls_left = 2
	turn_phase = "rolling"
	_update_dice_display()
	_update_buttons()
	# Reset enemy dice display
	for i in range(enemy_dice_count):
		enemy_dice_labels[i].text = "?"

func _end_combat(won: bool) -> void:
	turn_phase = "done"
	reroll_btn.disabled = true
	end_turn_btn.disabled = true
	# Add continue button
	var cont_btn = Button.new()
	if won:
		cont_btn.text = "CONTINUE"
	else:
		cont_btn.text = "GAME OVER"
	cont_btn.position = Vector2(540, 660)
	cont_btn.size = Vector2(200, 45)
	cont_btn.add_theme_font_size_override("font_size", 18)
	cont_btn.pressed.connect(func(): main.advance_after_combat(won))
	cont_btn.name = "ContinueBtn"
	add_child(cont_btn)
