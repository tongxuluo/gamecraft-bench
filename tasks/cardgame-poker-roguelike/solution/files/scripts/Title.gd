extends Node2D

var main: Node = null

const COLOR_FELT = Color(0.05, 0.22, 0.12)
const COLOR_FELT_DARK = Color(0.03, 0.14, 0.08)
const COLOR_GOLD = Color(0.85, 0.70, 0.20)
const COLOR_PANEL = Color(0.08, 0.08, 0.10)

func _ready() -> void:
	# Background - green felt
	var bg = ColorRect.new()
	bg.color = COLOR_FELT
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Dark strip at bottom
	var strip = ColorRect.new()
	strip.color = COLOR_FELT_DARK
	strip.position = Vector2(0, 500)
	strip.size = Vector2(1280, 220)
	add_child(strip)

	# Gold line
	var line = ColorRect.new()
	line.color = COLOR_GOLD
	line.position = Vector2(0, 498)
	line.size = Vector2(1280, 4)
	add_child(line)

	# Decorative card shapes in background
	for i in range(5):
		var card_bg = ColorRect.new()
		card_bg.color = Color(1, 1, 1, 0.05)
		card_bg.size = Vector2(80, 120)
		card_bg.position = Vector2(100 + i * 220, 80 + (i % 2) * 30)
		card_bg.rotation = deg_to_rad(-10 + i * 5)
		add_child(card_bg)

	# Title
	var title = Label.new()
	title.text = "POKER\nROGUELIKE"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 250)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Beat the blinds. Collect jokers. Score big."
	sub.position = Vector2(0, 380)
	sub.size = Vector2(1280, 50)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.8))
	sub.add_theme_font_size_override("font_size", 20)
	add_child(sub)

	# New Run button
	var btn = _make_button("NEW RUN", Vector2(490, 540))
	btn.pressed.connect(func(): main._enter_round())
	add_child(btn)

	# Stats button (decorative)
	var stats_btn = _make_button("STATS", Vector2(490, 620))
	stats_btn.disabled = true
	add_child(stats_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.12, 0.12, 0.15)
	var sb_dis = sb.duplicate()
	sb_dis.bg_color = Color(0.06, 0.06, 0.08)
	sb_dis.border_color = Color(0.3, 0.3, 0.3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb_dis)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.3))
	b.add_theme_font_size_override("font_size", 28)
	return b
