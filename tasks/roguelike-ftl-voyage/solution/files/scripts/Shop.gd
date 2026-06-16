extends Node2D

var main: Node = null

const COLOR_BG = Color(0.04, 0.05, 0.07)
const COLOR_PANEL = Color(0.1, 0.12, 0.16)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_ACCENT = Color(0.3, 0.6, 0.9)
const COLOR_GOLD = Color(0.9, 0.75, 0.2)
const COLOR_ITEM_BG = Color(0.08, 0.1, 0.14)

var scrap_label: Label = null
var hull_label: Label = null

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Shop title
	var title = Label.new()
	title.text = "SPACE STATION SHOP"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	# Scrap display
	scrap_label = Label.new()
	scrap_label.text = "SCRAP: " + str(main.scrap)
	scrap_label.position = Vector2(50, 90)
	scrap_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	scrap_label.add_theme_font_size_override("font_size", 22)
	add_child(scrap_label)

	# Hull display
	hull_label = Label.new()
	hull_label.text = "HULL: " + str(main.hull) + "/" + str(main.max_hull)
	hull_label.position = Vector2(250, 90)
	hull_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3))
	hull_label.add_theme_font_size_override("font_size", 22)
	add_child(hull_label)

	# Shop items
	var items = [
		{"name": "Repair Hull (+5)", "cost": 10, "action": "repair_hull"},
		{"name": "Fuel (+3)", "cost": 5, "action": "buy_fuel"},
		{"name": "Upgrade Weapons", "cost": 25, "action": "upgrade_weapons"},
		{"name": "Upgrade Shields", "cost": 25, "action": "upgrade_shields"},
		{"name": "Hire Crew Member", "cost": 30, "action": "hire_crew"},
	]

	var y_pos = 150
	for item in items:
		_add_shop_item(item, Vector2(200, y_pos))
		y_pos += 90

	# Leave button
	var leave_btn = _make_button("LEAVE SHOP", Vector2(540, 640))
	leave_btn.pressed.connect(func(): main._enter_sector_map())
	add_child(leave_btn)

func _add_shop_item(item: Dictionary, pos: Vector2) -> void:
	# Item background
	var item_bg = ColorRect.new()
	item_bg.color = COLOR_ITEM_BG
	item_bg.size = Vector2(880, 70)
	item_bg.position = pos
	add_child(item_bg)

	# Item border
	var border = ColorRect.new()
	border.color = Color(0.3, 0.35, 0.4)
	border.size = Vector2(880, 2)
	border.position = pos + Vector2(0, 68)
	add_child(border)

	# Item name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.position = pos + Vector2(20, 10)
	name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 20)
	add_child(name_lbl)

	# Cost
	var cost_lbl = Label.new()
	cost_lbl.text = str(item.cost) + " scrap"
	cost_lbl.position = pos + Vector2(20, 38)
	cost_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	cost_lbl.add_theme_font_size_override("font_size", 16)
	add_child(cost_lbl)

	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "BUY"
	buy_btn.position = pos + Vector2(750, 15)
	buy_btn.size = Vector2(100, 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.3, 0.15)
	sb.border_color = Color(0.3, 0.7, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	buy_btn.add_theme_stylebox_override("normal", sb)
	buy_btn.add_theme_stylebox_override("hover", sb)
	buy_btn.add_theme_stylebox_override("pressed", sb)
	buy_btn.add_theme_color_override("font_color", COLOR_TEXT)
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(_on_buy.bind(item))
	add_child(buy_btn)

func _on_buy(item: Dictionary) -> void:
	if main.scrap < item.cost:
		return
	main.scrap -= item.cost
	match item.action:
		"repair_hull":
			main.hull = min(main.hull + 5, main.max_hull)
		"buy_fuel":
			main.fuel += 3
		"upgrade_weapons":
			main.systems["weapons"].max_power += 1
			main.systems["weapons"].power += 1
		"upgrade_shields":
			main.systems["shields"].max_power += 1
			main.systems["shields"].power += 1
		"hire_crew":
			main.crew.append({"name": "Recruit", "room": "medbay", "hp": 4, "max_hp": 4})
	_update_labels()

func _update_labels() -> void:
	if scrap_label != null:
		scrap_label.text = "SCRAP: " + str(main.scrap)
	if hull_label != null:
		hull_label.text = "HULL: " + str(main.hull) + "/" + str(main.max_hull)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.25)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b
