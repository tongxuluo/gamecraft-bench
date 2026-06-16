extends Node2D

var main: Node = null

const COLOR_PCB := Color(0.05, 0.25, 0.12)
const COLOR_PCB_DARK := Color(0.03, 0.18, 0.08)
const COLOR_COPPER := Color(0.72, 0.45, 0.20)
const COLOR_GOLD := Color(0.85, 0.65, 0.13)
const COLOR_PANEL := Color(0.08, 0.30, 0.15)

func _ready() -> void:
	# Background - PCB green gradient
	var bg_top = ColorRect.new()
	bg_top.color = COLOR_PCB
	bg_top.size = Vector2(1280, 360)
	add_child(bg_top)
	var bg_bot = ColorRect.new()
	bg_bot.color = COLOR_PCB_DARK
	bg_bot.position = Vector2(0, 360)
	bg_bot.size = Vector2(1280, 360)
	add_child(bg_bot)

	# Copper trace decorations
	for i in range(8):
		var trace = ColorRect.new()
		trace.color = COLOR_COPPER.darkened(0.3)
		trace.position = Vector2(50 + i * 160, 0)
		trace.size = Vector2(3, 720)
		add_child(trace)
	for i in range(5):
		var trace = ColorRect.new()
		trace.color = COLOR_COPPER.darkened(0.3)
		trace.position = Vector2(0, 50 + i * 150)
		trace.size = Vector2(1280, 2)
		add_child(trace)

	# Solder pads decoration
	for i in range(12):
		var pad = ColorRect.new()
		pad.color = COLOR_GOLD.darkened(0.2)
		pad.size = Vector2(12, 12)
		pad.position = Vector2(100 + i * 100, 20)
		add_child(pad)
	for i in range(12):
		var pad = ColorRect.new()
		pad.color = COLOR_GOLD.darkened(0.2)
		pad.size = Vector2(12, 12)
		pad.position = Vector2(100 + i * 100, 688)
		add_child(pad)

	# Title
	var title = Label.new()
	title.text = "CIRCUIT WIZARD"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 200)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Digital Logic Puzzle"
	subtitle.position = Vector2(0, 240)
	subtitle.size = Vector2(1280, 60)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_COPPER)
	subtitle.add_theme_font_size_override("font_size", 28)
	add_child(subtitle)

	# Gate symbols decoration
	var symbols = Label.new()
	symbols.text = "AND   OR   NOT   XOR"
	symbols.position = Vector2(0, 300)
	symbols.size = Vector2(1280, 50)
	symbols.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbols.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.6))
	symbols.add_theme_font_size_override("font_size", 22)
	add_child(symbols)

	# Start button
	var start_btn = _make_button("START CAMPAIGN", Vector2(440, 420))
	start_btn.pressed.connect(func(): main._enter_game(0))
	add_child(start_btn)

	# Level select buttons
	var lv1_btn = _make_button("Level 1: AND Gate", Vector2(440, 510))
	lv1_btn.pressed.connect(func(): main._enter_game(0))
	add_child(lv1_btn)

	var lv2_btn = _make_button("Level 2: OR + NOT", Vector2(440, 580))
	lv2_btn.pressed.connect(func(): main._enter_game(1))
	add_child(lv2_btn)

	var lv3_btn = _make_button("Level 3: Multi-Gate", Vector2(440, 650))
	lv3_btn.pressed.connect(func(): main._enter_game(2))
	add_child(lv3_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(400, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_COPPER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.10, 0.35, 0.18)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.88))
	b.add_theme_font_size_override("font_size", 24)
	return b
