extends Node2D

var main: Node = null
var cleared: Array = []

const CHAMBERS := [
	{"name": "Basic Traversal", "desc": "Place portals to walk through walls"},
	{"name": "Laser Redirect", "desc": "Redirect a laser beam to hit the target"},
	{"name": "Momentum Launch", "desc": "Use gravity and portals to launch across gaps"},
]

const COLOR_BG := Color(0.92, 0.94, 0.96)
const COLOR_PANEL := Color(0.98, 0.98, 0.99)
const COLOR_DARK := Color(0.12, 0.14, 0.18)
const COLOR_BLUE := Color(0.15, 0.45, 0.95)
const COLOR_GREEN := Color(0.2, 0.7, 0.3)
const COLOR_GRID := Color(0.85, 0.87, 0.90)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Grid
	for x_i in range(0, 26):
		var line = ColorRect.new()
		line.color = COLOR_GRID
		line.position = Vector2(x_i * 50, 0)
		line.size = Vector2(1, 720)
		add_child(line)
	for y_i in range(0, 15):
		var line = ColorRect.new()
		line.color = COLOR_GRID
		line.position = Vector2(0, y_i * 50)
		line.size = Vector2(1280, 1)
		add_child(line)

	# Header
	var header = Label.new()
	header.text = "TEST CHAMBERS"
	header.position = Vector2(0, 30)
	header.size = Vector2(1280, 60)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_DARK)
	header.add_theme_font_size_override("font_size", 42)
	add_child(header)

	# Chamber cards
	for i in range(CHAMBERS.size()):
		var card = _make_chamber_card(i)
		add_child(card)

	# Back button
	var back = Button.new()
	back.text = "BACK"
	back.position = Vector2(540, 620)
	back.size = Vector2(200, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.3, 0.35)
	sb.set_corner_radius_all(4)
	back.add_theme_stylebox_override("normal", sb)
	back.add_theme_stylebox_override("hover", sb)
	back.add_theme_stylebox_override("pressed", sb)
	back.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): main._enter_title())
	add_child(back)

func _make_chamber_card(index: int) -> Node2D:
	var container = Node2D.new()
	var y_pos = 120 + index * 160
	container.position = Vector2(240, y_pos)

	# Card background
	var card_bg = ColorRect.new()
	card_bg.color = COLOR_PANEL
	card_bg.size = Vector2(800, 140)
	container.add_child(card_bg)

	# Card border
	var border = ColorRect.new()
	var is_cleared = cleared.has(index)
	border.color = COLOR_GREEN if is_cleared else COLOR_BLUE
	border.position = Vector2(-3, -3)
	border.size = Vector2(806, 146)
	border.z_index = -1
	container.add_child(border)

	# Chamber number
	var num_label = Label.new()
	num_label.text = "CHAMBER %02d" % (index + 1)
	num_label.position = Vector2(20, 15)
	num_label.size = Vector2(300, 40)
	num_label.add_theme_color_override("font_color", COLOR_DARK)
	num_label.add_theme_font_size_override("font_size", 28)
	container.add_child(num_label)

	# Chamber name
	var name_label = Label.new()
	name_label.text = CHAMBERS[index]["name"]
	name_label.position = Vector2(20, 55)
	name_label.size = Vector2(500, 30)
	name_label.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4))
	name_label.add_theme_font_size_override("font_size", 20)
	container.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = CHAMBERS[index]["desc"]
	desc_label.position = Vector2(20, 85)
	desc_label.size = Vector2(500, 30)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
	desc_label.add_theme_font_size_override("font_size", 16)
	container.add_child(desc_label)

	# Status
	var status = Label.new()
	status.text = "CLEARED" if is_cleared else "INCOMPLETE"
	status.position = Vector2(600, 55)
	status.size = Vector2(180, 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_color_override("font_color", COLOR_GREEN if is_cleared else Color(0.6, 0.6, 0.6))
	status.add_theme_font_size_override("font_size", 18)
	container.add_child(status)

	# Play button
	var play_btn = Button.new()
	play_btn.text = "ENTER"
	play_btn.position = Vector2(620, 85)
	play_btn.size = Vector2(150, 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_BLUE
	sb.set_corner_radius_all(4)
	play_btn.add_theme_stylebox_override("normal", sb)
	play_btn.add_theme_stylebox_override("hover", sb)
	play_btn.add_theme_stylebox_override("pressed", sb)
	play_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	play_btn.add_theme_font_size_override("font_size", 18)
	var idx = index
	play_btn.pressed.connect(func(): main._enter_game(idx))
	container.add_child(play_btn)

	return container
