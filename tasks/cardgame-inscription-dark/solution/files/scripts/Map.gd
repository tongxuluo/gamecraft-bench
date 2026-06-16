extends Node2D

var main: Node = null

const COLOR_BG = Color(0.05, 0.04, 0.03)
const COLOR_PATH_LINE = Color(0.35, 0.28, 0.18)
const COLOR_NODE_COMBAT = Color(0.75, 0.25, 0.25)
const COLOR_NODE_EVENT = Color(0.30, 0.60, 0.80)
const COLOR_NODE_SHOP = Color(0.80, 0.70, 0.20)
const COLOR_NODE_DONE = Color(0.30, 0.30, 0.30)
const COLOR_NODE_CURRENT = Color(0.90, 0.85, 0.60)
const COLOR_TEXT = Color(0.78, 0.72, 0.60)

# Map nodes: {id, type, x, y, connections[], label}
var map_nodes = [
	{"id": 0, "type": "start", "x": 640, "y": 620, "connections": [1, 2], "label": "START"},
	{"id": 1, "type": "combat", "x": 440, "y": 480, "connections": [3, 4], "label": "BATTLE"},
	{"id": 2, "type": "event", "x": 840, "y": 480, "connections": [4, 5], "label": "EVENT"},
	{"id": 3, "type": "combat", "x": 340, "y": 320, "connections": [6], "label": "BATTLE"},
	{"id": 4, "type": "event", "x": 640, "y": 320, "connections": [6, 7], "label": "STRANGER"},
	{"id": 5, "type": "shop", "x": 940, "y": 320, "connections": [7], "label": "TRADER"},
	{"id": 6, "type": "combat", "x": 480, "y": 160, "connections": [8], "label": "BOSS"},
	{"id": 7, "type": "combat", "x": 800, "y": 160, "connections": [8], "label": "BOSS"},
	{"id": 8, "type": "end", "x": 640, "y": 60, "connections": [], "label": "END"},
]

var current_node_id = 0
var visited_nodes = [0]
var node_buttons = []

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "THE PATH"
	title.position = Vector2(0, 10)
	title.size = Vector2(1280, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	# Draw connections first
	for node_data in map_nodes:
		for conn_id in node_data.connections:
			var target = _get_node_data(conn_id)
			if target != null:
				_draw_connection(Vector2(node_data.x, node_data.y), Vector2(target.x, target.y))

	# Draw nodes
	for node_data in map_nodes:
		var is_current = (node_data.id == current_node_id)
		var is_visited = visited_nodes.has(node_data.id)
		var is_available = _is_available(node_data.id)

		var color = _get_node_color(node_data, is_current, is_visited)
		var node_size = 40 if is_current else 32

		# Node background
		var node_rect = ColorRect.new()
		node_rect.color = color
		node_rect.position = Vector2(node_data.x - node_size / 2, node_data.y - node_size / 2)
		node_rect.size = Vector2(node_size, node_size)
		add_child(node_rect)

		# Border for current
		if is_current:
			var border = ColorRect.new()
			border.color = COLOR_NODE_CURRENT
			border.position = Vector2(node_data.x - node_size / 2 - 3, node_data.y - node_size / 2 - 3)
			border.size = Vector2(node_size + 6, 3)
			add_child(border)
			var border_b = ColorRect.new()
			border_b.color = COLOR_NODE_CURRENT
			border_b.position = Vector2(node_data.x - node_size / 2 - 3, node_data.y + node_size / 2)
			border_b.size = Vector2(node_size + 6, 3)
			add_child(border_b)

		# Label
		var lbl = Label.new()
		lbl.text = node_data.label
		lbl.position = Vector2(node_data.x - 50, node_data.y + node_size / 2 + 4)
		lbl.size = Vector2(100, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", color if not is_current else COLOR_NODE_CURRENT)
		lbl.add_theme_font_size_override("font_size", 14)
		add_child(lbl)

		# Clickable button for available nodes
		if is_available:
			var btn = Button.new()
			btn.flat = true
			btn.position = Vector2(node_data.x - node_size / 2 - 5, node_data.y - node_size / 2 - 5)
			btn.size = Vector2(node_size + 10, node_size + 10)
			var nid = node_data.id
			btn.pressed.connect(func(): _on_node_clicked(nid))
			add_child(btn)
			node_buttons.append(btn)

func _get_node_data(id: int):
	for n in map_nodes:
		if n.id == id:
			return n
	return null

func _is_available(id: int) -> bool:
	var cur = _get_node_data(current_node_id)
	if cur == null:
		return false
	return cur.connections.has(id)

func _get_node_color(node_data: Dictionary, is_current: bool, is_visited: bool) -> Color:
	if is_visited and not is_current:
		return COLOR_NODE_DONE
	match node_data.type:
		"combat":
			return COLOR_NODE_COMBAT
		"event":
			return COLOR_NODE_EVENT
		"shop":
			return COLOR_NODE_SHOP
		_:
			return Color(0.50, 0.45, 0.35)

func _draw_connection(from: Vector2, to: Vector2) -> void:
	# Draw a line using thin ColorRects
	var diff = to - from
	var length = diff.length()
	if length < 1.0:
		return
	var seg = ColorRect.new()
	seg.color = COLOR_PATH_LINE
	seg.size = Vector2(length, 3)
	seg.position = from
	seg.pivot_offset = Vector2(0, 1.5)
	seg.rotation = diff.angle()
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seg)

func _on_node_clicked(id: int) -> void:
	if not _is_available(id):
		return
	current_node_id = id
	if not visited_nodes.has(id):
		visited_nodes.append(id)

	var node_data = _get_node_data(id)
	if node_data == null:
		return

	match node_data.type:
		"combat":
			var battle_idx = 0 if id <= 3 else 1
			main._enter_battle(battle_idx)
		"event":
			main._enter_event()
		"shop":
			main._enter_event()
		_:
			main._enter_map()
