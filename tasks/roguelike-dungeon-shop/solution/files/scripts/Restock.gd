extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.10, 0.14)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)
const COLOR_GOLD = Color(0.90, 0.75, 0.20)
const COLOR_PANEL = Color(0.18, 0.16, 0.14)
const COLOR_LOOT = Color(0.40, 0.60, 0.45)

var loot_items: Array = []

const ITEM_POOL = [
	{"name": "Iron Sword", "type": "weapon", "base_price": 15},
	{"name": "Steel Axe", "type": "weapon", "base_price": 22},
	{"name": "Magic Staff", "type": "magic", "base_price": 28},
	{"name": "Health Potion", "type": "potion", "base_price": 8},
	{"name": "Mana Potion", "type": "potion", "base_price": 10},
	{"name": "Leather Shield", "type": "armor", "base_price": 12},
	{"name": "Chain Mail", "type": "armor", "base_price": 25},
	{"name": "Fire Scroll", "type": "magic", "base_price": 20},
	{"name": "Bandage", "type": "potion", "base_price": 5},
	{"name": "Steel Dagger", "type": "weapon", "base_price": 10},
	{"name": "Elixir", "type": "potion", "base_price": 18},
	{"name": "Enchanted Ring", "type": "magic", "base_price": 35},
]

func _ready() -> void:
	_generate_loot()
	_build_ui()

func _generate_loot() -> void:
	var num_items = 3 + main.shop_level
	for i in range(num_items):
		var template = ITEM_POOL[randi() % ITEM_POOL.size()]
		var item = template.duplicate()
		item["price"] = item.base_price
		loot_items.append(item)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "DUNGEON LOOT - Day " + str(main.day - 1) + " Complete!"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "You ventured into the dungeon and found:"
	subtitle.position = Vector2(0, 80)
	subtitle.size = Vector2(1280, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle.add_theme_font_size_override("font_size", 20)
	add_child(subtitle)

	# Display loot
	for i in range(loot_items.size()):
		var item = loot_items[i]
		var x = 150 + (i % 4) * 250
		var y = 140 + (i / 4) * 120

		var item_bg = ColorRect.new()
		item_bg.color = COLOR_LOOT
		item_bg.position = Vector2(x, y)
		item_bg.size = Vector2(220, 90)
		add_child(item_bg)

		var item_name = Label.new()
		item_name.text = item.name
		item_name.position = Vector2(x + 10, y + 10)
		item_name.size = Vector2(200, 25)
		item_name.add_theme_color_override("font_color", COLOR_TEXT)
		item_name.add_theme_font_size_override("font_size", 16)
		add_child(item_name)

		var item_type = Label.new()
		item_type.text = "[" + item.type + "] base: " + str(item.base_price) + "g"
		item_type.position = Vector2(x + 10, y + 40)
		item_type.size = Vector2(200, 20)
		item_type.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
		item_type.add_theme_font_size_override("font_size", 14)
		add_child(item_type)

	# Add all to inventory
	for item in loot_items:
		main.inventory.append(item)

	# Gold display
	var gold_label = Label.new()
	gold_label.text = "Gold: " + str(main.gold)
	gold_label.position = Vector2(0, 520)
	gold_label.size = Vector2(1280, 30)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 24)
	add_child(gold_label)

	# Continue button
	var continue_btn = _make_button("UPGRADE SHOP", Vector2(490, 580))
	continue_btn.pressed.connect(func(): main._enter_upgrade())
	add_child(continue_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 24)
	return b
