extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.07, 0.09)
const COLOR_PANEL = Color(0.14, 0.16, 0.19)
const COLOR_PANEL_LIGHT = Color(0.20, 0.22, 0.26)
const COLOR_ACCENT = Color(0.55, 0.60, 0.66)
const COLOR_GOLD = Color(0.85, 0.70, 0.30)
const COLOR_TEXT = Color(0.90, 0.92, 0.94)
const COLOR_RED = Color(0.85, 0.30, 0.30)
const COLOR_GREEN = Color(0.40, 0.75, 0.40)
const COLOR_BOARD = Color(0.12, 0.14, 0.16)
const COLOR_SLOT_EMPTY = Color(0.18, 0.20, 0.24)
const COLOR_SLOT_HOVER = Color(0.28, 0.32, 0.38)

const TRIBES = ["Beast", "Undead", "Mech", "Dragon", "Elemental"]
const TRIBE_COLORS = {
	"Beast": Color(0.6, 0.4, 0.2),
	"Undead": Color(0.4, 0.6, 0.4),
	"Mech": Color(0.5, 0.5, 0.6),
	"Dragon": Color(0.8, 0.3, 0.1),
	"Elemental": Color(0.3, 0.5, 0.8),
}
const SYNERGY_DESC = {
	"Beast": "+2 ATK to all Beasts",
	"Undead": "Resurrect once with 1 HP",
	"Mech": "+3 HP to all Mechs",
	"Dragon": "+4 ATK on kill",
	"Elemental": "Spell: 3 dmg to random enemy",
}

const CREATURE_POOL = [
	{"name": "Wolf", "tribe": "Beast", "atk": 3, "hp": 4, "cost": 1},
	{"name": "Bear", "tribe": "Beast", "atk": 5, "hp": 7, "cost": 3},
	{"name": "Raptor", "tribe": "Beast", "atk": 4, "hp": 3, "cost": 2},
	{"name": "Skeleton", "tribe": "Undead", "atk": 2, "hp": 3, "cost": 1},
	{"name": "Lich", "tribe": "Undead", "atk": 4, "hp": 5, "cost": 3},
	{"name": "Zombie", "tribe": "Undead", "atk": 3, "hp": 6, "cost": 2},
	{"name": "Drone", "tribe": "Mech", "atk": 2, "hp": 5, "cost": 1},
	{"name": "Golem", "tribe": "Mech", "atk": 3, "hp": 10, "cost": 4},
	{"name": "Turret", "tribe": "Mech", "atk": 4, "hp": 4, "cost": 2},
	{"name": "Drake", "tribe": "Dragon", "atk": 6, "hp": 6, "cost": 4},
	{"name": "Whelp", "tribe": "Dragon", "atk": 3, "hp": 3, "cost": 2},
	{"name": "Wyrm", "tribe": "Dragon", "atk": 8, "hp": 8, "cost": 5},
	{"name": "Spark", "tribe": "Elemental", "atk": 3, "hp": 3, "cost": 1},
	{"name": "Tide", "tribe": "Elemental", "atk": 4, "hp": 5, "cost": 3},
	{"name": "Inferno", "tribe": "Elemental", "atk": 6, "hp": 4, "cost": 4},
]

var shop_offers: Array = []  # 5 creature dicts
var shop_buttons: Array = []
var board_rects: Array = []
var bench_rects: Array = []
var gold_label: Label
var hp_label: Label
var round_label: Label
var synergy_label: Label
var info_label: Label
var selected_creature = null  # creature dict waiting to be placed
var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = hash(main.round_num * 1000 + main.player_gold)
	_roll_shop()
	_build_ui()

func _roll_shop() -> void:
	shop_offers.clear()
	for i in range(5):
		var idx = rng.randi_range(0, CREATURE_POOL.size() - 1)
		var c = CREATURE_POOL[idx].duplicate()
		c["color"] = TRIBE_COLORS[c.tribe]
		c["max_hp"] = c.hp
		shop_offers.append(c)

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Top HUD bar
	var top_bar = ColorRect.new()
	top_bar.color = COLOR_PANEL
	top_bar.size = Vector2(1280, 50)
	add_child(top_bar)
	var top_edge = ColorRect.new()
	top_edge.color = COLOR_ACCENT
	top_edge.position = Vector2(0, 48)
	top_edge.size = Vector2(1280, 2)
	add_child(top_edge)

	# Round label
	round_label = Label.new()
	round_label.text = "ROUND %d / 8" % main.round_num
	round_label.position = Vector2(20, 12)
	round_label.add_theme_color_override("font_color", COLOR_TEXT)
	round_label.add_theme_font_size_override("font_size", 22)
	add_child(round_label)

	# HP label
	hp_label = Label.new()
	hp_label.text = "HP: %d" % main.player_hp
	hp_label.position = Vector2(250, 12)
	hp_label.add_theme_color_override("font_color", COLOR_RED)
	hp_label.add_theme_font_size_override("font_size", 22)
	add_child(hp_label)

	# Gold label
	gold_label = Label.new()
	gold_label.text = "GOLD: %d" % main.player_gold
	gold_label.position = Vector2(450, 12)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 22)
	add_child(gold_label)

	# Level label
	var lvl_label = Label.new()
	lvl_label.text = "LVL: %d" % main.player_level
	lvl_label.position = Vector2(650, 12)
	lvl_label.add_theme_color_override("font_color", COLOR_GREEN)
	lvl_label.add_theme_font_size_override("font_size", 22)
	add_child(lvl_label)

	# Interest info
	var interest = mini(main.player_gold / 10, 5)
	var int_label = Label.new()
	int_label.text = "Interest: +%d" % interest
	int_label.position = Vector2(800, 12)
	int_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	int_label.add_theme_font_size_override("font_size", 18)
	add_child(int_label)

	# Shop section header
	var shop_header = Label.new()
	shop_header.text = "SHOP - Click to buy, then click a board slot to place"
	shop_header.position = Vector2(20, 60)
	shop_header.add_theme_color_override("font_color", COLOR_ACCENT)
	shop_header.add_theme_font_size_override("font_size", 16)
	add_child(shop_header)

	# Shop cards
	_build_shop_cards()

	# Board section
	var board_header = Label.new()
	board_header.text = "BOARD (Front Row / Back Row)"
	board_header.position = Vector2(20, 240)
	board_header.add_theme_color_override("font_color", COLOR_ACCENT)
	board_header.add_theme_font_size_override("font_size", 16)
	add_child(board_header)
	_build_board()

	# Synergy panel
	_build_synergy_panel()

	# Buttons: Reroll, Level Up, Fight
	_build_action_buttons()

	# Info label
	info_label = Label.new()
	info_label.text = ""
	info_label.position = Vector2(20, 690)
	info_label.size = Vector2(1280, 30)
	info_label.add_theme_color_override("font_color", COLOR_GOLD)
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)

func _build_shop_cards() -> void:
	shop_buttons.clear()
	for i in range(5):
		var c = shop_offers[i]
		var card = ColorRect.new()
		card.color = COLOR_PANEL_LIGHT
		card.position = Vector2(20 + i * 240, 85)
		card.size = Vector2(220, 140)
		add_child(card)

		var tribe_bar = ColorRect.new()
		tribe_bar.color = c.color
		tribe_bar.position = card.position + Vector2(0, 0)
		tribe_bar.size = Vector2(220, 6)
		add_child(tribe_bar)

		var name_lbl = Label.new()
		name_lbl.text = c.name
		name_lbl.position = card.position + Vector2(10, 12)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 20)
		add_child(name_lbl)

		var tribe_lbl = Label.new()
		tribe_lbl.text = c.tribe
		tribe_lbl.position = card.position + Vector2(10, 38)
		tribe_lbl.add_theme_color_override("font_color", c.color)
		tribe_lbl.add_theme_font_size_override("font_size", 16)
		add_child(tribe_lbl)

		var stats_lbl = Label.new()
		stats_lbl.text = "ATK: %d  HP: %d" % [c.atk, c.hp]
		stats_lbl.position = card.position + Vector2(10, 62)
		stats_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		stats_lbl.add_theme_font_size_override("font_size", 16)
		add_child(stats_lbl)

		var cost_lbl = Label.new()
		cost_lbl.text = "Cost: %d gold" % c.cost
		cost_lbl.position = card.position + Vector2(10, 86)
		cost_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		cost_lbl.add_theme_font_size_override("font_size", 16)
		add_child(cost_lbl)

		# Creature icon (colored rect)
		var icon = ColorRect.new()
		icon.color = c.color
		icon.position = card.position + Vector2(150, 40)
		icon.size = Vector2(50, 50)
		add_child(icon)
		var icon_inner = ColorRect.new()
		icon_inner.color = c.color * Color(1.3, 1.3, 1.3)
		icon_inner.position = card.position + Vector2(158, 48)
		icon_inner.size = Vector2(34, 34)
		add_child(icon_inner)

		var btn = Button.new()
		btn.flat = true
		btn.position = card.position
		btn.size = card.size
		btn.pressed.connect(_on_shop_buy.bind(i))
		add_child(btn)
		shop_buttons.append({"card": card, "btn": btn, "idx": i, "sold": false})

func _build_board() -> void:
	board_rects.clear()
	# Front row: slots 0-3, Back row: slots 4-7
	var labels_row = ["FRONT", "BACK"]
	for row in range(2):
		var row_lbl = Label.new()
		row_lbl.text = labels_row[row]
		row_lbl.position = Vector2(20, 270 + row * 120)
		row_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row_lbl.add_theme_font_size_override("font_size", 14)
		add_child(row_lbl)
		for col in range(4):
			var slot_idx = row * 4 + col
			var slot_bg = ColorRect.new()
			slot_bg.color = COLOR_SLOT_EMPTY
			slot_bg.position = Vector2(80 + col * 150, 265 + row * 120)
			slot_bg.size = Vector2(130, 105)
			add_child(slot_bg)

			var creature = main.board_slots[slot_idx]
			if creature != null:
				_draw_creature_in_slot(slot_bg.position, creature)

			var btn = Button.new()
			btn.flat = true
			btn.position = slot_bg.position
			btn.size = slot_bg.size
			btn.pressed.connect(_on_board_slot_click.bind(slot_idx))
			add_child(btn)
			board_rects.append({"rect": slot_bg, "btn": btn, "idx": slot_idx})

func _draw_creature_in_slot(pos: Vector2, creature: Dictionary) -> void:
	var icon = ColorRect.new()
	icon.color = creature.color
	icon.position = pos + Vector2(10, 10)
	icon.size = Vector2(50, 50)
	add_child(icon)
	var nm = Label.new()
	nm.text = creature.name
	nm.position = pos + Vector2(65, 10)
	nm.add_theme_color_override("font_color", COLOR_TEXT)
	nm.add_theme_font_size_override("font_size", 14)
	add_child(nm)
	var st = Label.new()
	st.text = "%d/%d" % [creature.atk, creature.hp]
	st.position = pos + Vector2(65, 30)
	st.add_theme_color_override("font_color", COLOR_ACCENT)
	st.add_theme_font_size_override("font_size", 14)
	add_child(st)
	var tr = Label.new()
	tr.text = creature.tribe
	tr.position = pos + Vector2(65, 50)
	tr.add_theme_color_override("font_color", creature.color)
	tr.add_theme_font_size_override("font_size", 12)
	add_child(tr)

func _build_synergy_panel() -> void:
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(780, 260)
	panel.size = Vector2(480, 250)
	add_child(panel)
	var panel_title = Label.new()
	panel_title.text = "SYNERGIES (need 3 of tribe)"
	panel_title.position = Vector2(790, 268)
	panel_title.add_theme_color_override("font_color", COLOR_ACCENT)
	panel_title.add_theme_font_size_override("font_size", 16)
	add_child(panel_title)

	# Count tribes on board
	var tribe_counts = {}
	for slot in main.board_slots:
		if slot != null:
			var t = slot.tribe
			if not tribe_counts.has(t):
				tribe_counts[t] = 0
			tribe_counts[t] += 1

	var y_off = 295
	for tribe in TRIBES:
		var count = tribe_counts.get(tribe, 0)
		var active = count >= 3
		var lbl = Label.new()
		lbl.text = "%s: %d/3 %s %s" % [tribe, count, "ACTIVE" if active else "", SYNERGY_DESC[tribe] if active else ""]
		lbl.position = Vector2(790, y_off)
		lbl.add_theme_color_override("font_color", TRIBE_COLORS[tribe] if active else Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", 14)
		add_child(lbl)

		# Tribe color indicator
		var ind = ColorRect.new()
		ind.color = TRIBE_COLORS[tribe] if active else Color(0.3, 0.3, 0.3)
		ind.position = Vector2(1220, y_off + 4)
		ind.size = Vector2(30, 14)
		add_child(ind)
		y_off += 28

	synergy_label = Label.new()
	synergy_label.text = ""
	synergy_label.position = Vector2(790, y_off + 10)
	synergy_label.add_theme_color_override("font_color", COLOR_GREEN)
	synergy_label.add_theme_font_size_override("font_size", 14)
	add_child(synergy_label)

func _build_action_buttons() -> void:
	# Reroll button
	var reroll_btn = _make_button("REROLL (1g)", Vector2(780, 530))
	reroll_btn.pressed.connect(_on_reroll)
	add_child(reroll_btn)

	# Level Up button
	var lvl_cost = 4 + main.player_level
	var lvlup_btn = _make_button("LEVEL UP (%dg)" % lvl_cost, Vector2(960, 530))
	lvlup_btn.pressed.connect(_on_level_up)
	add_child(lvlup_btn)

	# Fight button
	var fight_btn = _make_button("FIGHT!", Vector2(1140, 530))
	fight_btn.pressed.connect(_on_fight)
	add_child(fight_btn)
	# Make fight button stand out
	var fight_glow = ColorRect.new()
	fight_glow.color = Color(0.8, 0.3, 0.1, 0.3)
	fight_glow.position = Vector2(1138, 528)
	fight_glow.size = Vector2(124, 54)
	fight_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fight_glow)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(160, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_LIGHT
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 16)
	return b

func _on_shop_buy(idx: int) -> void:
	if idx >= shop_offers.size():
		return
	if shop_buttons[idx].sold:
		return
	var c = shop_offers[idx]
	if main.player_gold < c.cost:
		info_label.text = "Not enough gold!"
		return
	selected_creature = c.duplicate()
	selected_creature["color"] = TRIBE_COLORS[c.tribe]
	selected_creature["max_hp"] = c.hp
	shop_buttons[idx].sold = true
	shop_buttons[idx].card.color = Color(0.08, 0.08, 0.08)
	main.player_gold -= c.cost
	gold_label.text = "GOLD: %d" % main.player_gold
	info_label.text = "Bought %s! Click a board slot to place it." % c.name

func _on_board_slot_click(slot_idx: int) -> void:
	if selected_creature == null:
		# If slot has a creature, sell it
		if main.board_slots[slot_idx] != null:
			var c = main.board_slots[slot_idx]
			var refund = maxi(1, c.cost - 1)
			main.player_gold += refund
			gold_label.text = "GOLD: %d" % main.player_gold
			main.board_slots[slot_idx] = null
			info_label.text = "Sold %s for %d gold." % [c.name, refund]
			_rebuild()
		return
	main.board_slots[slot_idx] = selected_creature
	selected_creature = null
	info_label.text = "Creature placed!"
	_rebuild()

func _on_reroll() -> void:
	if main.player_gold < 1:
		info_label.text = "Not enough gold to reroll!"
		return
	main.player_gold -= 1
	gold_label.text = "GOLD: %d" % main.player_gold
	rng.seed = hash(main.round_num * 1000 + main.player_gold + randi())
	_roll_shop()
	_rebuild()
	info_label.text = "Shop rerolled!"

func _on_level_up() -> void:
	var cost = 4 + main.player_level
	if main.player_gold < cost:
		info_label.text = "Not enough gold to level up!"
		return
	main.player_gold -= cost
	main.player_level += 1
	gold_label.text = "GOLD: %d" % main.player_gold
	info_label.text = "Leveled up to %d!" % main.player_level
	_rebuild()

func _on_fight() -> void:
	# Check if player has at least one creature
	var has_creature = false
	for slot in main.board_slots:
		if slot != null:
			has_creature = true
			break
	if not has_creature:
		info_label.text = "Place at least one creature on the board!"
		return
	main._enter_battle()

func _rebuild() -> void:
	# Clear and rebuild UI
	for child in get_children():
		child.queue_free()
	_build_ui()

