extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.12, 0.06)
const COLOR_PANEL = Color(0.14, 0.18, 0.10)
const COLOR_ACCENT = Color(0.45, 0.75, 0.35)
const COLOR_TEXT = Color(0.9, 0.95, 0.85)

const SHOP_SEEDS = [
	{"id": "firebloom", "label": "FRB", "color": Color(0.9, 0.3, 0.1), "cost": 3, "atk": 3, "hp": 2, "effect": "damage", "price": 3},
	{"id": "ironoak", "label": "IOK", "color": Color(0.4, 0.35, 0.25), "cost": 4, "atk": 0, "hp": 12, "effect": "block", "price": 4},
	{"id": "moonlily", "label": "MNL", "color": Color(0.7, 0.6, 0.9), "cost": 5, "atk": 0, "hp": 4, "effect": "heal", "price": 5},
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var header = Label.new()
	header.text = "SEED SHOP - Floor %d Complete" % (main.floor_num - 1)
	header.position = Vector2(0, 30)
	header.size = Vector2(1280, 50)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_theme_font_size_override("font_size", 36)
	add_child(header)

	var res_label = Label.new()
	res_label.text = "Resources: %d" % main.resources
	res_label.position = Vector2(0, 80)
	res_label.size = Vector2(1280, 30)
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.5))
	res_label.add_theme_font_size_override("font_size", 22)
	add_child(res_label)

	# Season info
	var season_info = Label.new()
	season_info.text = "Current Season: %s" % main.get_season()
	season_info.position = Vector2(0, 115)
	season_info.size = Vector2(1280, 30)
	season_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	season_info.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
	season_info.add_theme_font_size_override("font_size", 18)
	add_child(season_info)

	# Shop items
	for i in range(SHOP_SEEDS.size()):
		var s = SHOP_SEEDS[i]
		var card = ColorRect.new()
		card.color = COLOR_PANEL
		card.position = Vector2(140 + i * 340, 180)
		card.size = Vector2(300, 280)
		add_child(card)

		var border = ColorRect.new()
		border.color = COLOR_ACCENT
		border.position = card.position
		border.size = Vector2(300, 4)
		add_child(border)

		var swatch = ColorRect.new()
		swatch.color = s.color
		swatch.position = card.position + Vector2(110, 30)
		swatch.size = Vector2(80, 80)
		add_child(swatch)

		var name_l = Label.new()
		name_l.text = s.id.to_upper()
		name_l.position = card.position + Vector2(0, 130)
		name_l.size = Vector2(300, 30)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_color_override("font_color", COLOR_TEXT)
		name_l.add_theme_font_size_override("font_size", 22)
		add_child(name_l)

		var info_l = Label.new()
		info_l.text = "Effect: %s\nEnergy: %d | HP: %d" % [s.effect, s.cost, s.hp]
		info_l.position = card.position + Vector2(20, 165)
		info_l.size = Vector2(260, 60)
		info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_l.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
		info_l.add_theme_font_size_override("font_size", 16)
		add_child(info_l)

		var btn = _make_button("BUY (%d)" % s.price, card.position + Vector2(60, 230))
		var idx = i
		btn.pressed.connect(func(): _buy(idx))
		add_child(btn)

	# Continue button
	var cont = _make_button("CONTINUE ->", Vector2(520, 560))
	cont.pressed.connect(func(): main._enter_floor())
	add_child(cont)

	# Compost option
	var compost = _make_button("COMPOST (remove seed)", Vector2(420, 630))
	compost.pressed.connect(func(): _compost())
	add_child(compost)

func _buy(idx: int) -> void:
	var s = SHOP_SEEDS[idx]
	if main.resources < s.price:
		return
	main.resources -= s.price
	var new_seed = s.duplicate()
	new_seed.erase("price")
	main.seed_deck.append(new_seed)

func _compost() -> void:
	if main.seed_deck.size() > 3:
		main.seed_deck.pop_back()

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(240, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.08)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b
