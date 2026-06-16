extends Node2D

var main: Node = null

const COLOR_BG = Color(0.10, 0.08, 0.06)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)
const COLOR_GOLD = Color(0.90, 0.75, 0.20)
const COLOR_PANEL = Color(0.22, 0.18, 0.14)
const COLOR_UPGRADE = Color(0.30, 0.50, 0.35)
const COLOR_DISABLED = Color(0.25, 0.22, 0.20)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "SHOP UPGRADES"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: " + str(main.gold)
	gold_label.position = Vector2(0, 80)
	gold_label.size = Vector2(1280, 30)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_label.add_theme_font_size_override("font_size", 22)
	add_child(gold_label)

	# Upgrade options
	_add_upgrade("More Shelves (+2)", "Expand display space", 40, 0, Vector2(140, 150))
	_add_upgrade("Security Guard", "Reduces thief chance", 60, 1, Vector2(140, 300))
	_add_upgrade("Better Stock", "Higher quality loot", 50, 2, Vector2(140, 450))

	# Next day button
	var next_btn = _make_button("START DAY " + str(main.day), Vector2(490, 620))
	next_btn.pressed.connect(func():
		main.shelves.clear()
		main._enter_shop()
	)
	add_child(next_btn)

func _add_upgrade(title_text: String, desc: String, cost: int, upgrade_id: int, pos: Vector2) -> void:
	var panel = ColorRect.new()
	var can_afford = main.gold >= cost
	var already_maxed = _is_maxed(upgrade_id)
	panel.color = COLOR_UPGRADE if (can_afford and not already_maxed) else COLOR_DISABLED
	panel.position = pos
	panel.size = Vector2(1000, 120)
	add_child(panel)

	var t = Label.new()
	t.text = title_text
	t.position = Vector2(pos.x + 20, pos.y + 15)
	t.size = Vector2(500, 30)
	t.add_theme_color_override("font_color", COLOR_TEXT)
	t.add_theme_font_size_override("font_size", 24)
	add_child(t)

	var d = Label.new()
	d.text = desc
	d.position = Vector2(pos.x + 20, pos.y + 50)
	d.size = Vector2(500, 25)
	d.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	d.add_theme_font_size_override("font_size", 16)
	add_child(d)

	var status = Label.new()
	if already_maxed:
		status.text = "MAXED"
		status.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		status.text = "Cost: " + str(cost) + "g"
		status.add_theme_color_override("font_color", COLOR_GOLD)
	status.position = Vector2(pos.x + 20, pos.y + 80)
	status.size = Vector2(200, 25)
	status.add_theme_font_size_override("font_size", 18)
	add_child(status)

	if can_afford and not already_maxed:
		var buy_btn = Button.new()
		buy_btn.text = "BUY"
		buy_btn.position = Vector2(pos.x + 850, pos.y + 35)
		buy_btn.size = Vector2(120, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.5, 0.3)
		sb.border_color = COLOR_GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		buy_btn.add_theme_stylebox_override("normal", sb)
		buy_btn.add_theme_stylebox_override("hover", sb)
		buy_btn.add_theme_stylebox_override("pressed", sb)
		buy_btn.add_theme_color_override("font_color", COLOR_TEXT)
		buy_btn.add_theme_font_size_override("font_size", 20)
		buy_btn.pressed.connect(func(): _buy_upgrade(upgrade_id, cost))
		add_child(buy_btn)

func _is_maxed(upgrade_id: int) -> bool:
	match upgrade_id:
		0: return main.max_shelves >= 8
		1: return main.security_level >= 3
		2: return main.shop_level >= 3
	return false

func _buy_upgrade(upgrade_id: int, cost: int) -> void:
	if main.gold < cost:
		return
	main.gold -= cost
	match upgrade_id:
		0: main.max_shelves = min(8, main.max_shelves + 2)
		1: main.security_level += 1
		2: main.shop_level += 1

	# Rebuild UI
	for child in get_children():
		child.queue_free()
	call_deferred("_build_ui")

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
