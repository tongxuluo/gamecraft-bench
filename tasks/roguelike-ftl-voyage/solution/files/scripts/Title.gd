extends Node2D

var main: Node = null

const COLOR_BG = Color(0.02, 0.03, 0.06)
const COLOR_STARS = Color(0.7, 0.75, 0.85)
const COLOR_SHIP = Color(0.25, 0.28, 0.35)
const COLOR_ACCENT = Color(0.3, 0.6, 0.9)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Stars
	var rng = RandomNumberGenerator.new()
	rng.seed = 123
	for i in range(80):
		var star = ColorRect.new()
		star.color = COLOR_STARS
		star.color.a = rng.randf_range(0.3, 0.9)
		star.size = Vector2(2, 2)
		star.position = Vector2(rng.randi_range(0, 1280), rng.randi_range(0, 720))
		add_child(star)

	# Ship silhouette (simple rectangle shape)
	var ship_body = ColorRect.new()
	ship_body.color = COLOR_SHIP
	ship_body.size = Vector2(300, 80)
	ship_body.position = Vector2(490, 280)
	add_child(ship_body)

	var ship_nose = ColorRect.new()
	ship_nose.color = COLOR_SHIP
	ship_nose.size = Vector2(60, 40)
	ship_nose.position = Vector2(790, 300)
	add_child(ship_nose)

	var ship_wing_top = ColorRect.new()
	ship_wing_top.color = COLOR_SHIP
	ship_wing_top.size = Vector2(120, 20)
	ship_wing_top.position = Vector2(520, 260)
	add_child(ship_wing_top)

	var ship_wing_bot = ColorRect.new()
	ship_wing_bot.color = COLOR_SHIP
	ship_wing_bot.size = Vector2(120, 20)
	ship_wing_bot.position = Vector2(520, 360)
	add_child(ship_wing_bot)

	# Title text
	var title = Label.new()
	title.text = "FTL VOYAGE"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "A Starship Roguelike"
	sub.position = Vector2(0, 160)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_ACCENT)
	sub.add_theme_font_size_override("font_size", 24)
	add_child(sub)

	# Start button
	var start_btn = _make_button("NEW VOYAGE", Vector2(490, 460))
	start_btn.pressed.connect(func(): main._enter_sector_map())
	add_child(start_btn)

	# Ship view button
	var ship_btn = _make_button("VIEW SHIP", Vector2(490, 540))
	ship_btn.pressed.connect(func(): main._enter_ship_view())
	add_child(ship_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 26)
	return b
