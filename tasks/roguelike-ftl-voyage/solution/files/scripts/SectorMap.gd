extends Node2D

var main: Node = null

const COLOR_BG = Color(0.03, 0.04, 0.07)
const COLOR_LINE = Color(0.3, 0.35, 0.45)
const COLOR_NODE = Color(0.2, 0.5, 0.8)
const COLOR_VISITED = Color(0.4, 0.4, 0.5)
const COLOR_CURRENT = Color(0.1, 0.9, 0.3)
const COLOR_EXIT = Color(0.9, 0.7, 0.1)
const COLOR_COMBAT = Color(0.9, 0.2, 0.2)
const COLOR_SHOP = Color(0.2, 0.8, 0.4)
const COLOR_EVENT = Color(0.7, 0.5, 0.9)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_HUD_BG = Color(0.08, 0.09, 0.12)

var node_buttons: Array = []

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# HUD bar at top
	var hud_bg = ColorRect.new()
	hud_bg.color = COLOR_HUD_BG
	hud_bg.size = Vector2(1280, 50)
	add_child(hud_bg)

	# Resource labels
	var fuel_lbl = Label.new()
	fuel_lbl.text = "FUEL: " + str(main.fuel)
	fuel_lbl.position = Vector2(20, 10)
	fuel_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	fuel_lbl.add_theme_font_size_override("font_size", 20)
	add_child(fuel_lbl)

	var scrap_lbl = Label.new()
	scrap_lbl.text = "SCRAP: " + str(main.scrap)
	scrap_lbl.position = Vector2(200, 10)
	scrap_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	scrap_lbl.add_theme_font_size_override("font_size", 20)
	add_child(scrap_lbl)

	var hull_lbl = Label.new()
	hull_lbl.text = "HULL: " + str(main.hull) + "/" + str(main.max_hull)
	hull_lbl.position = Vector2(400, 10)
	hull_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3))
	hull_lbl.add_theme_font_size_override("font_size", 20)
	add_child(hull_lbl)

	var sector_lbl = Label.new()
	sector_lbl.text = "SECTOR " + str(main.sector) + " / 3"
	sector_lbl.position = Vector2(600, 10)
	sector_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	sector_lbl.add_theme_font_size_override("font_size", 20)
	add_child(sector_lbl)

	# Draw connections first (lines)
	for i in range(main.sector_map.size()):
		var node_data = main.sector_map[i]
		for conn_idx in node_data.connections:
			var target = main.sector_map[conn_idx]
			var line = Line2D.new()
			line.add_point(Vector2(node_data.x, node_data.y))
			line.add_point(Vector2(target.x, target.y))
			line.width = 2.0
			line.default_color = COLOR_LINE
			add_child(line)

	# Draw nodes
	for i in range(main.sector_map.size()):
		var node_data = main.sector_map[i]
		var btn = Button.new()
		btn.size = Vector2(30, 30)
		btn.position = Vector2(node_data.x - 15, node_data.y - 15)
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		if i == main.current_node:
			sb.bg_color = COLOR_CURRENT
		elif i in main.visited_nodes:
			sb.bg_color = COLOR_VISITED
		elif node_data.type == "exit":
			sb.bg_color = COLOR_EXIT
		elif node_data.type == "combat":
			sb.bg_color = COLOR_COMBAT
		elif node_data.type == "shop":
			sb.bg_color = COLOR_SHOP
		elif node_data.type == "event":
			sb.bg_color = COLOR_EVENT
		else:
			sb.bg_color = COLOR_NODE
		sb.border_color = Color(0.9, 0.9, 0.9)
		sb.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb.duplicate())
		btn.add_theme_stylebox_override("pressed", sb)
		btn.text = ""
		var idx = i
		btn.pressed.connect(_on_node_pressed.bind(idx))
		add_child(btn)
		node_buttons.append(btn)

		# Node type label
		var type_lbl = Label.new()
		type_lbl.position = Vector2(node_data.x - 30, node_data.y + 18)
		type_lbl.add_theme_font_size_override("font_size", 12)
		type_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		if node_data.type == "exit":
			type_lbl.text = "EXIT"
		elif node_data.type == "combat":
			type_lbl.text = "FIGHT"
		elif node_data.type == "shop":
			type_lbl.text = "SHOP"
		elif node_data.type == "event":
			type_lbl.text = "EVENT"
		elif node_data.type == "start":
			type_lbl.text = "START"
		add_child(type_lbl)

	# Legend
	var legend_y = 500
	_add_legend_item("Current", COLOR_CURRENT, Vector2(50, legend_y))
	_add_legend_item("Combat", COLOR_COMBAT, Vector2(50, legend_y + 30))
	_add_legend_item("Shop", COLOR_SHOP, Vector2(50, legend_y + 60))
	_add_legend_item("Event", COLOR_EVENT, Vector2(50, legend_y + 90))
	_add_legend_item("Exit", COLOR_EXIT, Vector2(50, legend_y + 120))

	# Ship view button
	var ship_btn = Button.new()
	ship_btn.text = "SHIP VIEW"
	ship_btn.position = Vector2(1080, 650)
	ship_btn.size = Vector2(160, 50)
	var ship_sb = StyleBoxFlat.new()
	ship_sb.bg_color = Color(0.15, 0.18, 0.25)
	ship_sb.border_color = Color(0.4, 0.6, 0.9)
	ship_sb.set_border_width_all(2)
	ship_sb.set_corner_radius_all(4)
	ship_btn.add_theme_stylebox_override("normal", ship_sb)
	ship_btn.add_theme_stylebox_override("hover", ship_sb)
	ship_btn.add_theme_stylebox_override("pressed", ship_sb)
	ship_btn.add_theme_color_override("font_color", COLOR_TEXT)
	ship_btn.add_theme_font_size_override("font_size", 18)
	ship_btn.pressed.connect(func(): main._enter_ship_view())
	add_child(ship_btn)

func _add_legend_item(text: String, color: Color, pos: Vector2) -> void:
	var dot = ColorRect.new()
	dot.color = color
	dot.size = Vector2(14, 14)
	dot.position = pos
	add_child(dot)
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(20, -2)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.add_theme_font_size_override("font_size", 14)
	add_child(lbl)

func _on_node_pressed(idx: int) -> void:
	# Check if reachable from current node
	var current_data = main.sector_map[main.current_node]
	if not idx in current_data.connections:
		return
	if main.fuel <= 0:
		return
	main.fuel -= 1
	main.current_node = idx
	if not idx in main.visited_nodes:
		main.visited_nodes.append(idx)
	var node_data = main.sector_map[idx]
	if node_data.type == "exit":
		main.advance_sector()
	elif node_data.type == "combat":
		main._enter_combat({"type": "combat", "enemy_name": "Pirate Scout", "enemy_hull": 12, "enemy_weapons": 2})
	elif node_data.type == "shop":
		main._enter_shop()
	elif node_data.type == "event":
		main._enter_event(_random_event())
	else:
		main._enter_sector_map()

func _random_event() -> Dictionary:
	var events = [
		{"title": "Distress Signal", "text": "A damaged freighter sends a distress call. Do you investigate?", "choices": ["Help them (+scrap)", "Ignore"]},
		{"title": "Asteroid Field", "text": "Dense asteroids ahead. Navigate carefully or power through?", "choices": ["Careful (safe)", "Power through (risk hull)"]},
		{"title": "Abandoned Station", "text": "A derelict station floats nearby. Scavenge it?", "choices": ["Scavenge (+scrap, risk)", "Leave it"]},
	]
	return events[main.current_node % events.size()]
