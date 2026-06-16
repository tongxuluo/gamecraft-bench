extends Node2D

var main: Node = null

const COLOR_FELT = Color(0.05, 0.22, 0.12)
const COLOR_GOLD = Color(0.85, 0.70, 0.20)
const COLOR_PANEL = Color(0.08, 0.08, 0.10)
const COLOR_SHOP_BG = Color(0.06, 0.06, 0.10)

const JOKER_POOL = [
	{"name": "Greedy Joker", "desc": "+4 mult for pairs", "effect": "mult_add", "value": 4, "cost": 4},
	{"name": "Lusty Joker", "desc": "+20 chips always", "effect": "chips_add", "value": 20, "cost": 3},
	{"name": "Wrathful Joker", "desc": "x2 mult if flush", "effect": "mult_multiply", "value": 2, "cost": 6},
	{"name": "Gluttonous Joker", "desc": "+3 mult always", "effect": "mult_add", "value": 3, "cost": 5},
	{"name": "Banner", "desc": "+30 chips always", "effect": "chips_add", "value": 30, "cost": 5},
	{"name": "Mystic Summit", "desc": "+15 mult always", "effect": "mult_add", "value": 15, "cost": 7},
]

var shop_items: Array = []
var gold_label: Label = null
var item_nodes: Array = []

func _ready() -> void:
	_generate_shop()
	_build_ui()

func _generate_shop() -> void:
	shop_items.clear()
	var available = JOKER_POOL.duplicate()
	for i in range(mini(3, available.size())):
		var idx = main.rng.randi_range(0, available.size() - 1)
		shop_items.append(available[idx])
		available.remove_at(idx)

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_SHOP_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Header
	var header = ColorRect.new()
	header.color = COLOR_PANEL
	header.size = Vector2(1280, 70)
	add_child(header)

	var title = Label.new()
	title.text = "SHOP"
	title.position = Vector2(20, 10)
	title.size = Vector2(200, 50)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	var round_lbl = Label.new()
	round_lbl.text = "Round " + str(main.round_num) + " complete"
	round_lbl.position = Vector2(250, 10)
	round_lbl.size = Vector2(300, 50)
	round_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	round_lbl.add_theme_font_size_override("font_size", 20)
	add_child(round_lbl)

	# Gold
	gold_label = Label.new()
	gold_label.text = "$" + str(main.gold)
	gold_label.position = Vector2(1100, 10)
	gold_label.size = Vector2(160, 50)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 28)
	add_child(gold_label)

	# Joker slots display
	var joker_section_lbl = Label.new()
	joker_section_lbl.text = "Your Jokers (" + str(main.jokers.size()) + "/5)"
	joker_section_lbl.position = Vector2(40, 90)
	joker_section_lbl.size = Vector2(300, 30)
	joker_section_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	joker_section_lbl.add_theme_font_size_override("font_size", 16)
	add_child(joker_section_lbl)

	for i in range(main.jokers.size()):
		var j = main.jokers[i]
		var jcard = ColorRect.new()
		jcard.color = Color(0.4, 0.15, 0.6)
		jcard.position = Vector2(40 + i * 130, 125)
		jcard.size = Vector2(120, 60)
		add_child(jcard)
		var jname = Label.new()
		jname.text = j["name"]
		jname.position = Vector2(40 + i * 130, 130)
		jname.size = Vector2(120, 50)
		jname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		jname.add_theme_color_override("font_color", Color(1, 1, 1))
		jname.add_theme_font_size_override("font_size", 12)
		add_child(jname)

	# Shop items
	var shop_lbl = Label.new()
	shop_lbl.text = "Available Jokers"
	shop_lbl.position = Vector2(40, 210)
	shop_lbl.size = Vector2(300, 40)
	shop_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	shop_lbl.add_theme_font_size_override("font_size", 24)
	add_child(shop_lbl)

	for i in range(shop_items.size()):
		var item = shop_items[i]
		var card_bg = ColorRect.new()
		card_bg.color = Color(0.12, 0.12, 0.18)
		card_bg.position = Vector2(40 + i * 400, 260)
		card_bg.size = Vector2(360, 180)
		add_child(card_bg)

		var name_lbl = Label.new()
		name_lbl.text = item["name"]
		name_lbl.position = Vector2(60 + i * 400, 270)
		name_lbl.size = Vector2(320, 40)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 22)
		add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = item["desc"]
		desc_lbl.position = Vector2(60 + i * 400, 310)
		desc_lbl.size = Vector2(320, 40)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_lbl.add_theme_font_size_override("font_size", 16)
		add_child(desc_lbl)

		var cost_lbl = Label.new()
		cost_lbl.text = "$" + str(item["cost"])
		cost_lbl.position = Vector2(60 + i * 400, 350)
		cost_lbl.size = Vector2(100, 30)
		cost_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		cost_lbl.add_theme_font_size_override("font_size", 20)
		add_child(cost_lbl)

		var buy_btn = _make_button("BUY", Vector2(220 + i * 400, 380))
		buy_btn.size = Vector2(120, 45)
		var can_buy = main.gold >= item["cost"] and main.jokers.size() < 5
		buy_btn.disabled = not can_buy
		var item_ref = item
		buy_btn.pressed.connect(func(): _buy_joker(item_ref))
		add_child(buy_btn)

	# Remove card option
	var remove_lbl = Label.new()
	remove_lbl.text = "Remove a card from deck: $3"
	remove_lbl.position = Vector2(40, 480)
	remove_lbl.size = Vector2(400, 40)
	remove_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	remove_lbl.add_theme_font_size_override("font_size", 18)
	add_child(remove_lbl)

	var remove_btn = _make_button("REMOVE", Vector2(450, 475))
	remove_btn.size = Vector2(140, 40)
	remove_btn.disabled = main.gold < 3
	remove_btn.pressed.connect(func(): _remove_card())
	add_child(remove_btn)

	# Next round button
	var next_btn = _make_button("NEXT ROUND", Vector2(490, 620))
	next_btn.size = Vector2(300, 60)
	next_btn.pressed.connect(func(): main._enter_round())
	add_child(next_btn)

func _buy_joker(item: Dictionary) -> void:
	if main.gold < item["cost"] or main.jokers.size() >= 5:
		return
	main.gold -= item["cost"]
	main.jokers.append(item)
	# Rebuild UI
	for c in get_children():
		c.queue_free()
	_generate_shop()
	_build_ui()

func _remove_card() -> void:
	if main.gold < 3:
		return
	main.gold -= 3
	if main.deck.size() > 0:
		main.deck.remove_at(main.rng.randi_range(0, main.deck.size() - 1))
	gold_label.text = "$" + str(main.gold)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	var sb_dis = sb.duplicate()
	sb_dis.bg_color = Color(0.04, 0.04, 0.06)
	sb_dis.border_color = Color(0.3, 0.3, 0.3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb_dis)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.3))
	b.add_theme_font_size_override("font_size", 20)
	return b
