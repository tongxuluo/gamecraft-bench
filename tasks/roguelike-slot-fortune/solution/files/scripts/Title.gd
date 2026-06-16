extends Node2D

var main: Node = null

const COLOR_BG = Color(0.08, 0.06, 0.12)
const COLOR_GOLD = Color(0.95, 0.80, 0.20)
const COLOR_PANEL = Color(0.15, 0.12, 0.22)
const COLOR_ACCENT = Color(0.70, 0.55, 0.90)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Decorative slot machine frame
	var frame = ColorRect.new()
	frame.color = COLOR_PANEL
	frame.position = Vector2(390, 80)
	frame.size = Vector2(500, 300)
	add_child(frame)

	var frame_border = ColorRect.new()
	frame_border.color = COLOR_GOLD
	frame_border.position = Vector2(388, 78)
	frame_border.size = Vector2(504, 304)
	frame_border.z_index = -1
	add_child(frame_border)

	# Fake reel symbols on title
	var symbols = ["7", "$", "*"]
	for i in range(3):
		var lbl = Label.new()
		lbl.text = symbols[i]
		lbl.position = Vector2(440 + i * 150, 160)
		lbl.size = Vector2(100, 100)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 72)
		lbl.add_theme_color_override("font_color", COLOR_GOLD)
		add_child(lbl)

	var title = Label.new()
	title.text = "SLOT FORTUNE"
	title.position = Vector2(0, 410)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Slot Machine Roguelike"
	subtitle.position = Vector2(0, 480)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(subtitle)

	var start_btn = _make_button("START RUN", Vector2(490, 560))
	start_btn.pressed.connect(func(): main._enter_game())
	add_child(start_btn)

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
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_font_size_override("font_size", 28)
	return b
