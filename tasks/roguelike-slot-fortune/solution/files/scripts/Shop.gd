extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL = Color(0.15, 0.12, 0.22)
const COLOR_GOLD = Color(0.95, 0.80, 0.20)
const COLOR_ACCENT = Color(0.70, 0.55, 0.90)
const COLOR_GREEN = Color(0.25, 0.85, 0.35)
const COLOR_RED = Color(0.90, 0.25, 0.25)

const ALL_SYMBOLS = ["cherry", "coin", "gem", "cat", "milk", "ore", "furnace", "thief", "diamond", "clover", "bomb", "crown"]

var shop_offers: Array = []
var offer_buttons: Array = []
var remove_buttons: Array = []
var gold_label: Label = null
var pool_label: Label = null

func _ready() -> void:
	_draw_bg()
	_generate_offers()
	_draw_shop()
	_draw_remove_section()
	_draw_continue_btn()

func _draw_bg() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "SYMBOL SHOP"
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	add_child(title)

	gold_label = Label.new()
	gold_label.position = Vector2(50, 30)
	gold_label.size = Vector2(200, 40)
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.text = "Gold: " + str(main.gold)
	add_child(gold_label)

	pool_label = Label.new()
	pool_label.position = Vector2(50, 620)
	pool_label.size = Vector2(1180, 80)
	pool_label.add_theme_font_size_override("font_size", 16)
	pool_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_update_pool_label()
	add_child(pool_label)

func _generate_offers() -> void:
	shop_offers = []
	for i in range(3):
		var idx = main.rng.randi_range(0, ALL_SYMBOLS.size() - 1)
		shop_offers.append(ALL_SYMBOLS[idx])

func _get_symbol_cost(sym: String) -> int:
	match sym:
		"crown": return 12
		"diamond": return 10
		"clover": return 7
		"gem": return 6
		"furnace": return 5
		"cat": return 4
		"ore": return 3
		"cherry": return 3
		"coin": return 2
		"milk": return 2
		"thief": return 1
		"bomb": return 1
	return 3

func _draw_shop() -> void:
	var section_label = Label.new()
	section_label.text = "Add a symbol to your pool (click to buy):"
	section_label.position = Vector2(100, 90)
	section_label.size = Vector2(600, 30)
	section_label.add_theme_font_size_override("font_size", 20)
	section_label.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(section_label)

	for i in range(shop_offers.size()):
		var sym = shop_offers[i]
		var cost = _get_symbol_cost(sym)
		var sym_data = _get_sym_data(sym)
		var x = 150 + i * 350
		var y = 140

		var panel = ColorRect.new()
		panel.color = COLOR_PANEL
		panel.position = Vector2(x, y)
		panel.size = Vector2(300, 160)
		add_child(panel)

		var sym_lbl = Label.new()
		sym_lbl.text = sym_data[0]
		sym_lbl.position = Vector2(x + 20, y + 20)
		sym_lbl.size = Vector2(80, 80)
		sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sym_lbl.add_theme_font_size_override("font_size", 48)
		sym_lbl.add_theme_color_override("font_color", sym_data[2])
		add_child(sym_lbl)

		var name_lbl = Label.new()
		name_lbl.text = sym.to_upper() + "\nBase: " + str(sym_data[1]) + "  Cost: " + str(cost)
		name_lbl.position = Vector2(x + 110, y + 30)
		name_lbl.size = Vector2(180, 80)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
		add_child(name_lbl)

		var buy_btn = Button.new()
		buy_btn.text = "BUY (" + str(cost) + "g)"
		buy_btn.position = Vector2(x + 60, y + 110)
		buy_btn.size = Vector2(180, 40)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.35, 0.15)
		sb.border_color = COLOR_GREEN
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		buy_btn.add_theme_stylebox_override("normal", sb)
		buy_btn.add_theme_stylebox_override("hover", sb)
		buy_btn.add_theme_stylebox_override("pressed", sb)
		buy_btn.add_theme_color_override("font_color", COLOR_GREEN)
		buy_btn.add_theme_font_size_override("font_size", 18)
		buy_btn.pressed.connect(_buy_symbol.bind(i))
		buy_btn.disabled = main.gold < cost
		add_child(buy_btn)
		offer_buttons.append(buy_btn)

func _draw_remove_section() -> void:
	var section_label = Label.new()
	section_label.text = "Remove a symbol from your pool (cost: 3g, click to remove):"
	section_label.position = Vector2(100, 330)
	section_label.size = Vector2(700, 30)
	section_label.add_theme_font_size_override("font_size", 20)
	section_label.add_theme_color_override("font_color", COLOR_RED)
	add_child(section_label)

	var unique_syms = []
	for s in main.symbol_pool:
		if not unique_syms.has(s):
			unique_syms.append(s)

	var col_idx = 0
	for sym in unique_syms:
		var sym_data = _get_sym_data(sym)
		var count = main.symbol_pool.count(sym)
		var x = 100 + col_idx * 180
		var y = 370

		var btn = Button.new()
		btn.text = sym_data[0] + " " + sym.substr(0, 4) + " x" + str(count)
		btn.position = Vector2(x, y)
		btn.size = Vector2(160, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.35, 0.12, 0.12)
		sb.border_color = COLOR_RED
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.8))
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_remove_symbol.bind(sym))
		btn.disabled = main.gold < 3 or count <= 1
		add_child(btn)
		remove_buttons.append(btn)
		col_idx += 1
		if col_idx >= 6:
			break

func _draw_continue_btn() -> void:
	var btn = Button.new()
	btn.text = "NEXT ROUND"
	btn.position = Vector2(950, 540)
	btn.size = Vector2(250, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_GOLD)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): main._enter_game())
	add_child(btn)

func _buy_symbol(index: int) -> void:
	var sym = shop_offers[index]
	var cost = _get_symbol_cost(sym)
	if main.gold < cost:
		return
	main.gold -= cost
	main.symbol_pool.append(sym)
	gold_label.text = "Gold: " + str(main.gold)
	offer_buttons[index].disabled = true
	offer_buttons[index].text = "SOLD"
	_update_pool_label()

func _remove_symbol(sym: String) -> void:
	if main.gold < 3:
		return
	var idx = main.symbol_pool.find(sym)
	if idx == -1:
		return
	main.gold -= 3
	main.symbol_pool.remove_at(idx)
	gold_label.text = "Gold: " + str(main.gold)
	_update_pool_label()
	# Rebuild remove section (simple: just reload)
	for btn in remove_buttons:
		btn.queue_free()
	remove_buttons = []
	_draw_remove_section()

func _update_pool_label() -> void:
	var text = "Pool: "
	for s in main.symbol_pool:
		var sd = _get_sym_data(s)
		text += sd[0] + " "
	pool_label.text = text

func _get_sym_data(sym: String) -> Array:
	var SYMBOLS = {
		"cherry": ["C", 3, Color(0.90, 0.15, 0.20)],
		"coin": ["$", 2, Color(0.95, 0.80, 0.20)],
		"gem": ["G", 5, Color(0.20, 0.60, 0.95)],
		"cat": ["@", 0, Color(0.85, 0.65, 0.30)],
		"milk": ["M", 1, Color(0.95, 0.95, 0.95)],
		"ore": ["O", 2, Color(0.50, 0.50, 0.55)],
		"furnace": ["F", 0, Color(0.95, 0.40, 0.10)],
		"thief": ["T", -1, Color(0.30, 0.30, 0.35)],
		"diamond": ["D", 8, Color(0.70, 0.90, 1.0)],
		"clover": ["L", 4, Color(0.20, 0.80, 0.30)],
		"bomb": ["B", -2, Color(0.20, 0.20, 0.20)],
		"crown": ["K", 10, Color(1.0, 0.85, 0.0)]
	}
	return SYMBOLS[sym]
