extends Node2D

var main: Node = null

const COLOR_BG = Color(0.05, 0.04, 0.08)
const COLOR_PANEL = Color(0.12, 0.10, 0.16)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_COMBAT = Color(0.85, 0.35, 0.30)
const COLOR_REST = Color(0.30, 0.75, 0.40)
const COLOR_SHOP = Color(0.85, 0.75, 0.25)
const COLOR_BOSS = Color(0.75, 0.20, 0.60)
const COLOR_LINE = Color(0.35, 0.30, 0.25)
const COLOR_VISITED = Color(0.3, 0.3, 0.3)

# Map layout: 4 rows of nodes, each row has 3 nodes
# Row 0 = floor 1, Row 3 = boss
# Connections define which nodes link to which

var map_nodes: Array = []
var node_buttons: Array = []
var current_row: int = 0

# PLACEHOLDER_MAP_CONTINUE

func _ready() -> void:
	current_row = main.current_floor
	_generate_map()
	_build_ui()

func _generate_map() -> void:
	# Deterministic map based on seed
	var rng = RandomNumberGenerator.new()
	rng.seed = main.map_seed
	map_nodes.clear()

	# Row 0: 3 combat nodes
	map_nodes.append([
		{"type": "combat", "x": 200, "y": 550},
		{"type": "combat", "x": 640, "y": 550},
		{"type": "combat", "x": 1080, "y": 550},
	])
	# Row 1: combat, rest, combat
	map_nodes.append([
		{"type": "combat", "x": 300, "y": 400},
		{"type": "rest", "x": 640, "y": 400},
		{"type": "combat", "x": 980, "y": 400},
	])
	# Row 2: combat, shop, combat
	map_nodes.append([
		{"type": "combat", "x": 250, "y": 250},
		{"type": "shop", "x": 640, "y": 250},
		{"type": "combat", "x": 1030, "y": 250},
	])
	# Row 3: boss
	map_nodes.append([
		{"type": "boss", "x": 640, "y": 110},
	])

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Top HUD
	var hud_bg = ColorRect.new()
	hud_bg.color = COLOR_PANEL
	hud_bg.size = Vector2(1280, 50)
	add_child(hud_bg)
	var hud_line = ColorRect.new()
	hud_line.color = COLOR_ACCENT
	hud_line.position = Vector2(0, 48)
	hud_line.size = Vector2(1280, 2)
	add_child(hud_line)

	var class_label = Label.new()
	class_label.text = main.player_class
	class_label.position = Vector2(20, 10)
	class_label.add_theme_color_override("font_color", COLOR_ACCENT)
	class_label.add_theme_font_size_override("font_size", 22)
	add_child(class_label)

	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [main.player_hp, main.player_hp_max]
	hp_label.position = Vector2(200, 10)
	hp_label.add_theme_color_override("font_color", Color(0.85, 0.30, 0.30))
	hp_label.add_theme_font_size_override("font_size", 22)
	add_child(hp_label)

	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % main.player_gold
	gold_label.position = Vector2(420, 10)
	gold_label.add_theme_color_override("font_color", COLOR_SHOP)
	gold_label.add_theme_font_size_override("font_size", 22)
	add_child(gold_label)

	var floor_label = Label.new()
	floor_label.text = "Floor %d" % (current_row + 1)
	floor_label.position = Vector2(1100, 10)
	floor_label.size = Vector2(160, 30)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	floor_label.add_theme_color_override("font_color", COLOR_TEXT)
	floor_label.add_theme_font_size_override("font_size", 22)
	add_child(floor_label)

	# Draw connection lines first
	_draw_connections()

	# Draw nodes
	node_buttons.clear()
	for row_idx in range(map_nodes.size()):
		var row = map_nodes[row_idx]
		for col_idx in range(row.size()):
			var node_data = row[col_idx]
			_draw_node(node_data, row_idx, col_idx)

	# Map title
	var map_title = Label.new()
	map_title.text = "- THE SPIRE -"
	map_title.position = Vector2(0, 660)
	map_title.size = Vector2(1280, 40)
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_color_override("font_color", Color(0.4, 0.35, 0.30))
	map_title.add_theme_font_size_override("font_size", 18)
	add_child(map_title)

func _draw_connections() -> void:
	# Draw lines between rows
	for row_idx in range(map_nodes.size() - 1):
		var row = map_nodes[row_idx]
		var next_row = map_nodes[row_idx + 1]
		for node_data in row:
			for next_data in next_row:
				var from_pos = Vector2(node_data.x, node_data.y)
				var to_pos = Vector2(next_data.x, next_data.y)
				# Only connect if reasonably close horizontally
				if abs(from_pos.x - to_pos.x) < 500:
					_draw_line_rect(from_pos, to_pos)

func _draw_line_rect(from: Vector2, to: Vector2) -> void:
	var diff = to - from
	var length = diff.length()
	if length < 1:
		return
	var line = ColorRect.new()
	line.color = COLOR_LINE
	line.size = Vector2(length, 2)
	line.position = from
	line.pivot_offset = Vector2(0, 1)
	line.rotation = diff.angle()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

func _draw_node(node_data: Dictionary, row_idx: int, col_idx: int) -> void:
	var pos = Vector2(node_data.x, node_data.y)
	var color = COLOR_COMBAT
	var label_text = "?"
	var node_size = 50

	match node_data.type:
		"combat":
			color = COLOR_COMBAT
			label_text = "!"
		"rest":
			color = COLOR_REST
			label_text = "R"
		"shop":
			color = COLOR_SHOP
			label_text = "$"
		"boss":
			color = COLOR_BOSS
			label_text = "BOSS"
			node_size = 70

	var is_available = (row_idx == current_row)
	var is_past = (row_idx < current_row)

	if is_past:
		color = COLOR_VISITED

	# Node background
	var node_bg = ColorRect.new()
	node_bg.color = color * Color(0.3, 0.3, 0.3) if not is_available else color * Color(0.5, 0.5, 0.5)
	node_bg.position = pos - Vector2(node_size / 2.0, node_size / 2.0)
	node_bg.size = Vector2(node_size, node_size)
	add_child(node_bg)

	# Node border
	var border = ColorRect.new()
	border.color = color if is_available else color * Color(0.6, 0.6, 0.6)
	border.position = pos - Vector2(node_size / 2.0, node_size / 2.0)
	border.size = Vector2(node_size, 3)
	add_child(border)
	var border_bot = ColorRect.new()
	border_bot.color = border.color
	border_bot.position = pos + Vector2(-node_size / 2.0, node_size / 2.0 - 3)
	border_bot.size = Vector2(node_size, 3)
	add_child(border_bot)

	# Label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = pos - Vector2(node_size / 2.0, node_size / 2.0)
	lbl.size = Vector2(node_size, node_size)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", COLOR_TEXT if is_available else Color(0.5, 0.5, 0.5))
	lbl.add_theme_font_size_override("font_size", 20 if node_data.type != "boss" else 18)
	add_child(lbl)

	# Clickable button if available
	if is_available:
		var btn = Button.new()
		btn.flat = true
		btn.position = pos - Vector2(node_size / 2.0, node_size / 2.0)
		btn.size = Vector2(node_size, node_size)
		var node_type = node_data.type
		btn.pressed.connect(func(): _on_node_clicked(node_type))
		add_child(btn)

func _on_node_clicked(node_type: String) -> void:
	main.current_floor += 1
	match node_type:
		"combat":
			main._enter_combat(false)
		"rest":
			main._enter_rest()
		"shop":
			# Shop just heals a bit and returns to map
			main.player_gold -= 10
			main.player_hp = min(main.player_hp + 10, main.player_hp_max)
			main._enter_map()
		"boss":
			main._enter_combat(true)
