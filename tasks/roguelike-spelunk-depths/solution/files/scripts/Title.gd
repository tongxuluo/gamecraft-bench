extends Node2D

var main: Node = null

const COLOR_BG_TOP = Color(0.05, 0.04, 0.08)
const COLOR_BG_BOT = Color(0.12, 0.08, 0.04)
const COLOR_ROCK = Color(0.3, 0.22, 0.15)
const COLOR_ACCENT = Color(0.85, 0.65, 0.25)

func _ready() -> void:
	var bg_top = ColorRect.new()
	bg_top.color = COLOR_BG_TOP
	bg_top.size = Vector2(1280, 360)
	add_child(bg_top)
	var bg_bot = ColorRect.new()
	bg_bot.color = COLOR_BG_BOT
	bg_bot.position = Vector2(0, 360)
	bg_bot.size = Vector2(1280, 360)
	add_child(bg_bot)

	# Cave entrance rocks
	for i in range(6):
		var rock = ColorRect.new()
		rock.color = COLOR_ROCK
		rock.position = Vector2(50 + i * 210, 330 + (i % 2) * 20)
		rock.size = Vector2(80, 50 + i * 5)
		add_child(rock)

	# Depth markers
	for i in range(4):
		var marker = ColorRect.new()
		marker.color = Color(0.5, 0.4, 0.2)
		marker.position = Vector2(600, 400 + i * 60)
		marker.size = Vector2(80, 3)
		add_child(marker)
		var depth_l = Label.new()
		depth_l.text = "-%dm" % ((i + 1) * 100)
		depth_l.position = Vector2(690, 392 + i * 60)
		depth_l.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
		depth_l.add_theme_font_size_override("font_size", 16)
		add_child(depth_l)

	var stripe = ColorRect.new()
	stripe.color = COLOR_ACCENT
	stripe.position = Vector2(0, 358)
	stripe.size = Vector2(1280, 4)
	add_child(stripe)

	var title = Label.new()
	title.text = "SPELUNK\nDEPTHS"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 240)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Procedural Platformer Roguelike"
	subtitle.position = Vector2(0, 270)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	subtitle.add_theme_font_size_override("font_size", 20)
	add_child(subtitle)

	var start_btn = _make_button("DESCEND", Vector2(490, 460))
	start_btn.pressed.connect(func(): main._enter_cave())
	add_child(start_btn)

	var info = Label.new()
	info.text = "Arrows: move | SPACE: jump | DOWN: pick up | UP: rope"
	info.position = Vector2(0, 620)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.45, 0.3))
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.14, 0.06)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	b.add_theme_font_size_override("font_size", 28)
	return b
