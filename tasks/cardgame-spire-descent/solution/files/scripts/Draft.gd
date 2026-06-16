extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.05, 0.09)
const COLOR_PANEL = Color(0.14, 0.12, 0.18)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_RED = Color(0.85, 0.30, 0.30)
const COLOR_BLUE = Color(0.30, 0.50, 0.85)
const COLOR_GREEN = Color(0.30, 0.75, 0.40)
const COLOR_RARE = Color(0.85, 0.65, 0.20)

const CARD_POOL = [
	{"name": "Cleave", "cost": 1, "type": "attack", "value": 8, "rarity": "common"},
	{"name": "Iron Wave", "cost": 1, "type": "attack", "value": 5, "rarity": "common"},
	{"name": "Pommel Strike", "cost": 1, "type": "attack", "value": 9, "rarity": "common"},
	{"name": "Shrug It Off", "cost": 1, "type": "skill", "value": 8, "rarity": "common"},
	{"name": "Armaments", "cost": 1, "type": "skill", "value": 5, "rarity": "common"},
	{"name": "Clothesline", "cost": 2, "type": "attack", "value": 12, "rarity": "uncommon"},
	{"name": "Flame Barrier", "cost": 2, "type": "skill", "value": 12, "rarity": "uncommon"},
	{"name": "Carnage", "cost": 2, "type": "attack", "value": 20, "rarity": "uncommon"},
	{"name": "Impervious", "cost": 2, "type": "skill", "value": 20, "rarity": "rare"},
	{"name": "Bludgeon", "cost": 3, "type": "attack", "value": 32, "rarity": "rare"},
	{"name": "Barricade", "cost": 3, "type": "skill", "value": 25, "rarity": "rare"},
	{"name": "Whirlwind", "cost": 2, "type": "attack", "value": 15, "rarity": "uncommon"},
]

var offered_cards: Array = []

func _ready() -> void:
	_generate_offers()
	_build_ui()

func _generate_offers() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = main.map_seed + main.fights_won * 53
	var pool = CARD_POOL.duplicate(true)
	offered_cards.clear()
	for i in range(3):
		if pool.size() == 0:
			break
		var idx = rng.randi_range(0, pool.size() - 1)
		offered_cards.append(pool[idx])
		pool.remove_at(idx)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "CARD REWARD - Choose 1"
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Pick a card to add to your deck, or skip"
	subtitle.position = Vector2(0, 85)
	subtitle.size = Vector2(1280, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	subtitle.add_theme_font_size_override("font_size", 18)
	add_child(subtitle)

	# Display 3 cards
	var card_w = 280
	var card_h = 380
	var spacing = 40
	var total_w = 3 * card_w + 2 * spacing
	var start_x = (1280 - total_w) / 2.0

	for i in range(offered_cards.size()):
		var card = offered_cards[i]
		var x_pos = start_x + i * (card_w + spacing)
		var y_pos = 140.0

		# Card panel
		var panel = ColorRect.new()
		panel.color = COLOR_PANEL
		panel.position = Vector2(x_pos, y_pos)
		panel.size = Vector2(card_w, card_h)
		add_child(panel)

		# Rarity border
		var rarity_color = COLOR_TEXT
		match card.rarity:
			"common":
				rarity_color = Color(0.6, 0.6, 0.6)
			"uncommon":
				rarity_color = COLOR_BLUE
			"rare":
				rarity_color = COLOR_RARE

		var border_top = ColorRect.new()
		border_top.color = rarity_color
		border_top.position = Vector2(x_pos, y_pos)
		border_top.size = Vector2(card_w, 4)
		add_child(border_top)
		var border_bot = ColorRect.new()
		border_bot.color = rarity_color
		border_bot.position = Vector2(x_pos, y_pos + card_h - 4)
		border_bot.size = Vector2(card_w, 4)
		add_child(border_bot)
		var border_left = ColorRect.new()
		border_left.color = rarity_color
		border_left.position = Vector2(x_pos, y_pos)
		border_left.size = Vector2(4, card_h)
		add_child(border_left)
		var border_right = ColorRect.new()
		border_right.color = rarity_color
		border_right.position = Vector2(x_pos + card_w - 4, y_pos)
		border_right.size = Vector2(4, card_h)
		add_child(border_right)

		# Energy cost
		var cost_bg = ColorRect.new()
		cost_bg.color = Color(0.20, 0.18, 0.12)
		cost_bg.position = Vector2(x_pos + 15, y_pos + 20)
		cost_bg.size = Vector2(45, 45)
		add_child(cost_bg)
		var cost_lbl = Label.new()
		cost_lbl.text = str(card.cost)
		cost_lbl.position = Vector2(x_pos + 15, y_pos + 20)
		cost_lbl.size = Vector2(45, 45)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.20))
		cost_lbl.add_theme_font_size_override("font_size", 26)
		add_child(cost_lbl)

		# Card name
		var name_lbl = Label.new()
		name_lbl.text = card.name
		name_lbl.position = Vector2(x_pos, y_pos + 80)
		name_lbl.size = Vector2(card_w, 35)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 22)
		add_child(name_lbl)

		# Type icon area
		var type_color = COLOR_RED if card.type == "attack" else COLOR_BLUE
		var type_rect = ColorRect.new()
		type_rect.color = type_color * Color(0.3, 0.3, 0.3)
		type_rect.position = Vector2(x_pos + 60, y_pos + 130)
		type_rect.size = Vector2(160, 100)
		add_child(type_rect)
		var type_inner = ColorRect.new()
		type_inner.color = type_color * Color(0.6, 0.6, 0.6)
		type_inner.position = Vector2(x_pos + 80, y_pos + 150)
		type_inner.size = Vector2(120, 60)
		add_child(type_inner)

		# Type label
		var type_lbl = Label.new()
		type_lbl.text = card.type.to_upper()
		type_lbl.position = Vector2(x_pos, y_pos + 245)
		type_lbl.size = Vector2(card_w, 25)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_color_override("font_color", type_color)
		type_lbl.add_theme_font_size_override("font_size", 16)
		add_child(type_lbl)

		# Value
		var val_lbl = Label.new()
		var val_text = "Deal %d damage" % card.value if card.type == "attack" else "Gain %d block" % card.value
		val_lbl.text = val_text
		val_lbl.position = Vector2(x_pos, y_pos + 280)
		val_lbl.size = Vector2(card_w, 30)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		val_lbl.add_theme_font_size_override("font_size", 18)
		add_child(val_lbl)

		# Rarity label
		var rarity_lbl = Label.new()
		rarity_lbl.text = card.rarity.to_upper()
		rarity_lbl.position = Vector2(x_pos, y_pos + 320)
		rarity_lbl.size = Vector2(card_w, 25)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.add_theme_color_override("font_color", rarity_color)
		rarity_lbl.add_theme_font_size_override("font_size", 14)
		add_child(rarity_lbl)

		# Pick button
		var btn = Button.new()
		btn.text = "PICK"
		btn.position = Vector2(x_pos + 70, y_pos + card_h - 55)
		btn.size = Vector2(140, 45)
		var sb = StyleBoxFlat.new()
		sb.bg_color = rarity_color * Color(0.3, 0.3, 0.3)
		sb.border_color = rarity_color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT)
		btn.add_theme_font_size_override("font_size", 18)
		var card_data = card
		btn.pressed.connect(func(): _pick_card(card_data))
		add_child(btn)

	# Skip button
	var skip_btn = Button.new()
	skip_btn.text = "SKIP"
	skip_btn.position = Vector2(565, 560)
	skip_btn.size = Vector2(150, 45)
	var sb_skip = StyleBoxFlat.new()
	sb_skip.bg_color = Color(0.10, 0.09, 0.12)
	sb_skip.border_color = Color(0.4, 0.38, 0.35)
	sb_skip.set_border_width_all(1)
	sb_skip.set_corner_radius_all(4)
	skip_btn.add_theme_stylebox_override("normal", sb_skip)
	skip_btn.add_theme_stylebox_override("hover", sb_skip)
	skip_btn.add_theme_stylebox_override("pressed", sb_skip)
	skip_btn.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_skip)
	add_child(skip_btn)

	# Deck count
	var deck_lbl = Label.new()
	deck_lbl.text = "Deck: %d cards" % main.player_deck.size()
	deck_lbl.position = Vector2(0, 620)
	deck_lbl.size = Vector2(1280, 30)
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	deck_lbl.add_theme_font_size_override("font_size", 16)
	add_child(deck_lbl)

func _pick_card(card: Dictionary) -> void:
	var new_card = {"name": card.name, "cost": card.cost, "type": card.type, "value": card.value}
	main.player_deck.append(new_card)
	main._enter_map()

func _skip() -> void:
	main._enter_map()
