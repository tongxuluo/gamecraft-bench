extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_PANEL = Color(0.15, 0.12, 0.22)
const COLOR_ACCENT = Color(0.45, 0.75, 0.55)
const COLOR_PURPLE = Color(0.55, 0.30, 0.70)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Decorative cauldron (simple shapes)
	var cauldron_body = ColorRect.new()
	cauldron_body.color = Color(0.20, 0.18, 0.25)
	cauldron_body.position = Vector2(540, 180)
	cauldron_body.size = Vector2(200, 140)
	add_child(cauldron_body)

	var cauldron_rim = ColorRect.new()
	cauldron_rim.color = Color(0.30, 0.28, 0.35)
	cauldron_rim.position = Vector2(530, 170)
	cauldron_rim.size = Vector2(220, 20)
	add_child(cauldron_rim)

	# Bubbles
	for i in range(5):
		var bubble = ColorRect.new()
		bubble.color = COLOR_ACCENT.lerp(COLOR_PURPLE, float(i) / 5.0)
		bubble.position = Vector2(570 + i * 28, 140 - i * 15)
		bubble.size = Vector2(12 + i * 3, 12 + i * 3)
		add_child(bubble)

	var title = Label.new()
	title.text = "POTION CRAFT"
	title.position = Vector2(0, 340)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "An Alchemy Roguelike"
	subtitle.position = Vector2(0, 410)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_PURPLE)
	subtitle.add_theme_font_size_override("font_size", 24)
	add_child(subtitle)

	var start_btn = _make_button("START BREW", Vector2(490, 490))
	start_btn.pressed.connect(func(): main.reset_run(); main._enter_map())
	add_child(start_btn)

	var quit_btn = _make_button("QUIT", Vector2(490, 570))
	quit_btn.pressed.connect(func(): get_tree().quit())
	add_child(quit_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 26)
	return b
