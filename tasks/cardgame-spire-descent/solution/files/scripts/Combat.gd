extends Node2D

var main: Node = null
var is_boss: bool = false

const COLOR_BG = Color(0.06, 0.05, 0.09)
const COLOR_PANEL = Color(0.12, 0.10, 0.16)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_RED = Color(0.85, 0.30, 0.30)
const COLOR_BLUE = Color(0.30, 0.50, 0.85)
const COLOR_GREEN = Color(0.30, 0.75, 0.40)
const COLOR_CARD_BG = Color(0.16, 0.14, 0.20)
const COLOR_ENERGY = Color(0.90, 0.75, 0.20)

var energy: int = 3
var energy_max: int = 3
var block: int = 0
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []

var enemy_hp: int = 30
var enemy_hp_max: int = 30
var enemy_block: int = 0
var enemy_intent: Dictionary = {}
var enemy_name: String = "Cultist"

var turn_number: int = 0
var combat_over: bool = false

var hand_buttons: Array = []
var hp_label: Label = null
var enemy_hp_label: Label = null
var energy_label: Label = null
var block_label: Label = null
var intent_label: Label = null
var enemy_block_label: Label = null
var feedback_label: Label = null
var end_turn_btn: Button = null

# PLACEHOLDER_COMBAT_CONTINUE

func _ready() -> void:
	_setup_enemy()
	_setup_draw_pile()
	_build_ui()
	_start_turn()

func _setup_enemy() -> void:
	if is_boss:
		enemy_name = "The Guardian"
		enemy_hp = 80
		enemy_hp_max = 80
	else:
		var enemies = ["Cultist", "Jaw Worm", "Louse", "Slime"]
		var idx = (main.fights_won + main.map_seed) % enemies.size()
		enemy_name = enemies[idx]
		enemy_hp = 25 + main.fights_won * 8
		enemy_hp_max = enemy_hp

func _setup_draw_pile() -> void:
	draw_pile = main.player_deck.duplicate(true)
	# Shuffle deterministically
	var rng = RandomNumberGenerator.new()
	rng.seed = main.map_seed + main.fights_won * 100 + 7
	for i in range(draw_pile.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp
	discard_pile.clear()
	hand.clear()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Arena floor
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.08, 0.07, 0.12)
	floor_rect.position = Vector2(0, 400)
	floor_rect.size = Vector2(1280, 320)
	add_child(floor_rect)
	var floor_line = ColorRect.new()
	floor_line.color = COLOR_ACCENT * Color(0.5, 0.5, 0.5)
	floor_line.position = Vector2(0, 398)
	floor_line.size = Vector2(1280, 2)
	add_child(floor_line)

	# Enemy display
	var enemy_color = COLOR_RED if not is_boss else Color(0.75, 0.20, 0.60)
	var enemy_size = Vector2(120, 140) if not is_boss else Vector2(180, 200)
	var enemy_x = 800 if not is_boss else 750
	var enemy_y = 180 if not is_boss else 130

	var enemy_body = ColorRect.new()
	enemy_body.color = enemy_color * Color(0.5, 0.5, 0.5)
	enemy_body.position = Vector2(enemy_x, enemy_y)
	enemy_body.size = enemy_size
	add_child(enemy_body)
	var enemy_inner = ColorRect.new()
	enemy_inner.color = enemy_color
	enemy_inner.position = Vector2(enemy_x + 15, enemy_y + 15)
	enemy_inner.size = enemy_size - Vector2(30, 30)
	add_child(enemy_inner)

	# Enemy name
	var name_lbl = Label.new()
	name_lbl.text = enemy_name
	name_lbl.position = Vector2(enemy_x, enemy_y - 30)
	name_lbl.size = Vector2(enemy_size.x, 25)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 18)
	add_child(name_lbl)

	# Enemy HP
	enemy_hp_label = Label.new()
	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_hp_max]
	enemy_hp_label.position = Vector2(enemy_x, enemy_y + enemy_size.y + 5)
	enemy_hp_label.size = Vector2(enemy_size.x, 25)
	enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_hp_label.add_theme_color_override("font_color", COLOR_RED)
	enemy_hp_label.add_theme_font_size_override("font_size", 18)
	add_child(enemy_hp_label)

	# Enemy block
	enemy_block_label = Label.new()
	enemy_block_label.text = ""
	enemy_block_label.position = Vector2(enemy_x, enemy_y + enemy_size.y + 28)
	enemy_block_label.size = Vector2(enemy_size.x, 25)
	enemy_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_block_label.add_theme_color_override("font_color", COLOR_BLUE)
	enemy_block_label.add_theme_font_size_override("font_size", 16)
	add_child(enemy_block_label)

	# Intent display
	intent_label = Label.new()
	intent_label.text = ""
	intent_label.position = Vector2(enemy_x - 20, enemy_y - 60)
	intent_label.size = Vector2(enemy_size.x + 40, 25)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.add_theme_color_override("font_color", COLOR_ENERGY)
	intent_label.add_theme_font_size_override("font_size", 18)
	add_child(intent_label)

	# Player character
	var player_body = ColorRect.new()
	player_body.color = COLOR_GREEN * Color(0.5, 0.5, 0.5)
	player_body.position = Vector2(200, 220)
	player_body.size = Vector2(100, 120)
	add_child(player_body)
	var player_inner = ColorRect.new()
	player_inner.color = COLOR_GREEN
	player_inner.position = Vector2(215, 235)
	player_inner.size = Vector2(70, 90)
	add_child(player_inner)

	# Player HP
	hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [main.player_hp, main.player_hp_max]
	hp_label.position = Vector2(160, 350)
	hp_label.size = Vector2(180, 25)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", COLOR_RED)
	hp_label.add_theme_font_size_override("font_size", 20)
	add_child(hp_label)

	# Block display
	block_label = Label.new()
	block_label.text = ""
	block_label.position = Vector2(160, 375)
	block_label.size = Vector2(180, 25)
	block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label.add_theme_color_override("font_color", COLOR_BLUE)
	block_label.add_theme_font_size_override("font_size", 18)
	add_child(block_label)

	# Energy display
	energy_label = Label.new()
	energy_label.text = "%d/%d" % [energy, energy_max]
	energy_label.position = Vector2(30, 430)
	energy_label.size = Vector2(80, 40)
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_color_override("font_color", COLOR_ENERGY)
	energy_label.add_theme_font_size_override("font_size", 28)
	add_child(energy_label)
	var energy_bg = ColorRect.new()
	energy_bg.color = COLOR_PANEL
	energy_bg.position = Vector2(30, 425)
	energy_bg.size = Vector2(80, 50)
	energy_bg.z_index = -1
	add_child(energy_bg)

	# End Turn button
	end_turn_btn = Button.new()
	end_turn_btn.text = "END TURN"
	end_turn_btn.position = Vector2(1080, 420)
	end_turn_btn.size = Vector2(160, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_ACCENT * Color(0.5, 0.5, 0.5)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	end_turn_btn.add_theme_stylebox_override("normal", sb)
	end_turn_btn.add_theme_stylebox_override("hover", sb)
	end_turn_btn.add_theme_stylebox_override("pressed", sb)
	end_turn_btn.add_theme_color_override("font_color", COLOR_TEXT)
	end_turn_btn.add_theme_font_size_override("font_size", 20)
	end_turn_btn.pressed.connect(_on_end_turn)
	add_child(end_turn_btn)

	# Feedback label
	feedback_label = Label.new()
	feedback_label.text = ""
	feedback_label.position = Vector2(400, 390)
	feedback_label.size = Vector2(480, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", COLOR_TEXT)
	feedback_label.add_theme_font_size_override("font_size", 18)
	add_child(feedback_label)

	# Draw/Discard pile labels
	var draw_lbl = Label.new()
	draw_lbl.text = "Draw"
	draw_lbl.position = Vector2(30, 680)
	draw_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	draw_lbl.add_theme_font_size_override("font_size", 14)
	add_child(draw_lbl)
	var discard_lbl = Label.new()
	discard_lbl.text = "Discard"
	discard_lbl.position = Vector2(1200, 680)
	discard_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	discard_lbl.add_theme_font_size_override("font_size", 14)
	add_child(discard_lbl)

func _start_turn() -> void:
	turn_number += 1
	energy = energy_max
	block = 0
	_update_block_display()
	_draw_cards(5)
	_roll_enemy_intent()
	_refresh_hand_display()
	_update_energy_display()

func _draw_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.size() == 0:
			if discard_pile.size() == 0:
				break
			draw_pile = discard_pile.duplicate(true)
			discard_pile.clear()
			# Shuffle
			var rng = RandomNumberGenerator.new()
			rng.seed = main.map_seed + turn_number * 37 + i
			for j in range(draw_pile.size() - 1, 0, -1):
				var k = rng.randi_range(0, j)
				var tmp = draw_pile[j]
				draw_pile[j] = draw_pile[k]
				draw_pile[k] = tmp
		if draw_pile.size() > 0:
			hand.append(draw_pile.pop_back())

func _roll_enemy_intent() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = main.map_seed + turn_number * 13 + enemy_hp
	var roll = rng.randi_range(0, 2)
	if roll == 0:
		var dmg = 8 + (4 if is_boss else 0) + turn_number * 2
		enemy_intent = {"type": "attack", "value": dmg}
		intent_label.text = "Intent: ATK %d" % dmg
		intent_label.add_theme_color_override("font_color", COLOR_RED)
	elif roll == 1:
		var blk = 6 + (5 if is_boss else 0)
		enemy_intent = {"type": "defend", "value": blk}
		intent_label.text = "Intent: DEF %d" % blk
		intent_label.add_theme_color_override("font_color", COLOR_BLUE)
	else:
		var dmg = 5 + turn_number
		enemy_intent = {"type": "attack", "value": dmg}
		intent_label.text = "Intent: ATK %d" % dmg
		intent_label.add_theme_color_override("font_color", COLOR_RED)

func _refresh_hand_display() -> void:
	# Clear old hand buttons
	for btn_data in hand_buttons:
		if is_instance_valid(btn_data.node):
			btn_data.node.queue_free()
	hand_buttons.clear()

	var card_w = 140
	var card_h = 180
	var spacing = 10
	var total_w = hand.size() * (card_w + spacing) - spacing
	var start_x = (1280 - total_w) / 2.0
	var y_pos = 500.0

	for i in range(hand.size()):
		var card = hand[i]
		var x_pos = start_x + i * (card_w + spacing)

		var card_node = Control.new()
		card_node.position = Vector2(x_pos, y_pos)
		card_node.size = Vector2(card_w, card_h)
		add_child(card_node)

		# Card background
		var card_bg = ColorRect.new()
		card_bg.color = COLOR_CARD_BG
		card_bg.size = Vector2(card_w, card_h)
		card_node.add_child(card_bg)

		# Card border color based on type
		var border_color = COLOR_RED if card.type == "attack" else COLOR_BLUE
		var card_border = ColorRect.new()
		card_border.color = border_color
		card_border.size = Vector2(card_w, 3)
		card_node.add_child(card_border)
		var card_border_bot = ColorRect.new()
		card_border_bot.color = border_color
		card_border_bot.position = Vector2(0, card_h - 3)
		card_border_bot.size = Vector2(card_w, 3)
		card_node.add_child(card_border_bot)

		# Energy cost (top left)
		var cost_bg = ColorRect.new()
		cost_bg.color = COLOR_ENERGY * Color(0.4, 0.4, 0.4)
		cost_bg.position = Vector2(5, 8)
		cost_bg.size = Vector2(28, 28)
		card_node.add_child(cost_bg)
		var cost_lbl = Label.new()
		cost_lbl.text = str(card.cost)
		cost_lbl.position = Vector2(5, 8)
		cost_lbl.size = Vector2(28, 28)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", COLOR_ENERGY)
		cost_lbl.add_theme_font_size_override("font_size", 18)
		card_node.add_child(cost_lbl)

		# Card name
		var name_lbl = Label.new()
		name_lbl.text = card.name
		name_lbl.position = Vector2(0, 45)
		name_lbl.size = Vector2(card_w, 25)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 16)
		card_node.add_child(name_lbl)

		# Card type icon area
		var type_rect = ColorRect.new()
		type_rect.color = border_color * Color(0.3, 0.3, 0.3)
		type_rect.position = Vector2(30, 80)
		type_rect.size = Vector2(80, 50)
		card_node.add_child(type_rect)

		# Card value
		var val_lbl = Label.new()
		var val_text = ""
		if card.type == "attack":
			val_text = "DMG %d" % card.value
		else:
			val_text = "BLK %d" % card.value
		val_lbl.text = val_text
		val_lbl.position = Vector2(0, 140)
		val_lbl.size = Vector2(card_w, 25)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_color_override("font_color", border_color)
		val_lbl.add_theme_font_size_override("font_size", 15)
		card_node.add_child(val_lbl)

		# Clickable button
		var btn = Button.new()
		btn.flat = true
		btn.size = Vector2(card_w, card_h)
		var card_idx = i
		btn.pressed.connect(func(): _play_card(card_idx))
		card_node.add_child(btn)

		# Dim if not enough energy
		if card.cost > energy:
			card_bg.color = Color(0.08, 0.07, 0.10)
			cost_lbl.add_theme_color_override("font_color", COLOR_RED)

		hand_buttons.append({"node": card_node, "idx": i})

func _play_card(idx: int) -> void:
	if combat_over:
		return
	if idx < 0 or idx >= hand.size():
		return
	var card = hand[idx]
	if card.cost > energy:
		feedback_label.text = "Not enough energy!"
		feedback_label.add_theme_color_override("font_color", COLOR_RED)
		return

	energy -= card.cost
	_update_energy_display()

	if card.type == "attack":
		var dmg = card.value
		_deal_damage_to_enemy(dmg)
		feedback_label.text = "%s deals %d damage!" % [card.name, dmg]
		feedback_label.add_theme_color_override("font_color", COLOR_RED)
	elif card.type == "skill":
		block += card.value
		_update_block_display()
		feedback_label.text = "%s gains %d block!" % [card.name, card.value]
		feedback_label.add_theme_color_override("font_color", COLOR_BLUE)

	# Move card to discard
	discard_pile.append(card)
	hand.remove_at(idx)
	_refresh_hand_display()

	# Check enemy death
	if enemy_hp <= 0:
		_win_combat()

func _deal_damage_to_enemy(dmg: int) -> void:
	if enemy_block > 0:
		if dmg <= enemy_block:
			enemy_block -= dmg
			dmg = 0
		else:
			dmg -= enemy_block
			enemy_block = 0
	enemy_hp -= dmg
	if enemy_hp < 0:
		enemy_hp = 0
	enemy_hp_label.text = "HP: %d/%d" % [enemy_hp, enemy_hp_max]
	_update_enemy_block_display()

func _on_end_turn() -> void:
	if combat_over:
		return
	# Discard hand
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	_refresh_hand_display()

	# Enemy turn
	_enemy_turn()

	# Check player death
	if main.player_hp <= 0:
		_lose_combat()
		return

	# Start new player turn
	_start_turn()

func _enemy_turn() -> void:
	enemy_block = 0
	if enemy_intent.type == "attack":
		var dmg = enemy_intent.value
		if block > 0:
			if dmg <= block:
				block -= dmg
				dmg = 0
			else:
				dmg -= block
				block = 0
		main.player_hp -= dmg
		if main.player_hp < 0:
			main.player_hp = 0
		hp_label.text = "HP: %d/%d" % [main.player_hp, main.player_hp_max]
		feedback_label.text = "%s attacks for %d!" % [enemy_name, enemy_intent.value]
		feedback_label.add_theme_color_override("font_color", COLOR_RED)
	elif enemy_intent.type == "defend":
		enemy_block = enemy_intent.value
		feedback_label.text = "%s gains %d block!" % [enemy_name, enemy_intent.value]
		feedback_label.add_theme_color_override("font_color", COLOR_BLUE)
	_update_enemy_block_display()

func _update_energy_display() -> void:
	energy_label.text = "%d/%d" % [energy, energy_max]

func _update_block_display() -> void:
	if block > 0:
		block_label.text = "Block: %d" % block
	else:
		block_label.text = ""

func _update_enemy_block_display() -> void:
	if enemy_block > 0:
		enemy_block_label.text = "Block: %d" % enemy_block
	else:
		enemy_block_label.text = ""

func _win_combat() -> void:
	combat_over = true
	main.fights_won += 1
	feedback_label.text = "VICTORY!"
	feedback_label.add_theme_color_override("font_color", COLOR_GREEN)
	intent_label.text = "DEFEATED"
	intent_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	end_turn_btn.text = "CONTINUE"
	end_turn_btn.pressed.disconnect(_on_end_turn)
	end_turn_btn.pressed.connect(_on_continue)

func _on_continue() -> void:
	if is_boss:
		main._enter_win()
	else:
		main._enter_draft()

func _lose_combat() -> void:
	combat_over = true
	feedback_label.text = "DEFEATED..."
	feedback_label.add_theme_color_override("font_color", COLOR_RED)
	end_turn_btn.text = "GAME OVER"
	end_turn_btn.pressed.disconnect(_on_end_turn)
	end_turn_btn.pressed.connect(func(): main._enter_lose())
