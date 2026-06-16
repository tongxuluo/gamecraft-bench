extends Node2D

var main: Node = null

const COLOR_BG_DARK = Color(0.08, 0.06, 0.04)
const COLOR_BG_WARM = Color(0.14, 0.10, 0.07)
const COLOR_WOOD = Color(0.35, 0.22, 0.10)
const COLOR_WOOD_LIGHT = Color(0.50, 0.35, 0.18)
const COLOR_GOLD = Color(0.85, 0.70, 0.30)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)
const COLOR_PANEL = Color(0.20, 0.15, 0.10)

func _ready() -> void:
	# Background - tavern interior
	var bg = ColorRect.new()
	bg.color = COLOR_BG_DARK
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Warm upper area (tavern wall)
	var wall = ColorRect.new()
	wall.color = COLOR_BG_WARM
	wall.size = Vector2(1280, 400)
	add_child(wall)

	# Wooden bar counter
	var bar = ColorRect.new()
	bar.color = COLOR_WOOD
	bar.position = Vector2(0, 400)
	bar.size = Vector2(1280, 20)
	add_child(bar)
	var bar_edge = ColorRect.new()
	bar_edge.color = COLOR_WOOD_LIGHT
	bar_edge.position = Vector2(0, 398)
	bar_edge.size = Vector2(1280, 4)
	add_child(bar_edge)

	# Wooden sign above bar
	var sign_bg = ColorRect.new()
	sign_bg.color = COLOR_WOOD
	sign_bg.position = Vector2(340, 80)
	sign_bg.size = Vector2(600, 140)
	add_child(sign_bg)
	var sign_border = ColorRect.new()
	sign_border.color = COLOR_WOOD_LIGHT
	sign_border.position = Vector2(344, 84)
	sign_border.size = Vector2(592, 132)
	add_child(sign_border)
	var sign_inner = ColorRect.new()
	sign_inner.color = COLOR_WOOD
	sign_inner.position = Vector2(350, 90)
	sign_inner.size = Vector2(580, 120)
	add_child(sign_inner)

	# Game title on sign
	var title = Label.new()
	title.text = "CREATURE CLASH"
	title.position = Vector2(340, 100)
	title.size = Vector2(600, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "AUTOBATTLER"
	subtitle.position = Vector2(340, 155)
	subtitle.size = Vector2(600, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle.add_theme_font_size_override("font_size", 28)
	add_child(subtitle)

	# Creature silhouettes at tables (decorative rects)
	_draw_silhouette(Vector2(100, 320), Vector2(50, 70), Color(0.15, 0.12, 0.08))
	_draw_silhouette(Vector2(200, 340), Vector2(40, 50), Color(0.12, 0.10, 0.06))
	_draw_silhouette(Vector2(1000, 310), Vector2(60, 80), Color(0.13, 0.11, 0.07))
	_draw_silhouette(Vector2(1100, 330), Vector2(45, 60), Color(0.14, 0.10, 0.06))

	# Tables
	_draw_table(Vector2(80, 390), 120)
	_draw_table(Vector2(980, 390), 140)

	# Lantern glow effects
	_draw_lantern(Vector2(280, 60))
	_draw_lantern(Vector2(980, 60))

	# Find Match button (styled as tavern door)
	var door_bg = ColorRect.new()
	door_bg.color = COLOR_WOOD
	door_bg.position = Vector2(440, 480)
	door_bg.size = Vector2(400, 100)
	add_child(door_bg)
	var door_inner = ColorRect.new()
	door_inner.color = Color(0.28, 0.18, 0.08)
	door_inner.position = Vector2(448, 488)
	door_inner.size = Vector2(384, 84)
	add_child(door_inner)

	var find_btn = Button.new()
	find_btn.text = "FIND MATCH"
	find_btn.position = Vector2(440, 480)
	find_btn.size = Vector2(400, 100)
	find_btn.flat = true
	find_btn.add_theme_color_override("font_color", COLOR_GOLD)
	find_btn.add_theme_font_size_override("font_size", 36)
	find_btn.pressed.connect(_on_find_match)
	add_child(find_btn)

	# Version text
	var ver = Label.new()
	ver.text = "v1.0 - Oracle Solution"
	ver.position = Vector2(0, 690)
	ver.size = Vector2(1280, 30)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3))
	ver.add_theme_font_size_override("font_size", 14)
	add_child(ver)

func _draw_silhouette(pos: Vector2, sz: Vector2, col: Color) -> void:
	var s = ColorRect.new()
	s.color = col
	s.position = pos
	s.size = sz
	add_child(s)

func _draw_table(pos: Vector2, width: float) -> void:
	var t = ColorRect.new()
	t.color = Color(0.25, 0.16, 0.08)
	t.position = pos
	t.size = Vector2(width, 12)
	add_child(t)

func _draw_lantern(pos: Vector2) -> void:
	var glow = ColorRect.new()
	glow.color = Color(0.9, 0.7, 0.2, 0.15)
	glow.position = pos - Vector2(30, 10)
	glow.size = Vector2(60, 40)
	add_child(glow)
	var lamp = ColorRect.new()
	lamp.color = Color(0.9, 0.7, 0.2, 0.6)
	lamp.position = pos
	lamp.size = Vector2(12, 20)
	add_child(lamp)

func _on_find_match() -> void:
	main.round_num = 1
	main.player_hp = 100
	main.player_gold = 3
	main.player_level = 1
	for i in range(8):
		main.board_slots[i] = null
	for i in range(4):
		main.bench_slots[i] = null
	main._enter_shop()
