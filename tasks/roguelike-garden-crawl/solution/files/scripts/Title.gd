extends Node2D

var main: Node = null

const COLOR_BG_TOP = Color(0.12, 0.18, 0.10)
const COLOR_BG_BOT = Color(0.06, 0.08, 0.05)
const COLOR_STONE = Color(0.25, 0.22, 0.20)
const COLOR_ACCENT = Color(0.45, 0.75, 0.35)

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

	# Dungeon stones decoration
	for i in range(8):
		var stone = ColorRect.new()
		stone.color = COLOR_STONE
		stone.position = Vector2(80 + i * 150, 380)
		stone.size = Vector2(60, 40)
		add_child(stone)

	# Vine decorations
	for i in range(5):
		var vine = ColorRect.new()
		vine.color = Color(0.3, 0.6, 0.2)
		vine.position = Vector2(100 + i * 240, 340)
		vine.size = Vector2(8, 60)
		add_child(vine)

	var stripe = ColorRect.new()
	stripe.color = COLOR_ACCENT
	stripe.position = Vector2(0, 358)
	stripe.size = Vector2(1280, 4)
	add_child(stripe)

	var title = Label.new()
	title.text = "GARDEN\nCRAWL"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 240)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.05))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Garden-Dungeon Roguelike"
	subtitle.position = Vector2(0, 280)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	var start_btn = _make_button("START RUN", Vector2(490, 460))
	start_btn.pressed.connect(func(): main._enter_floor())
	add_child(start_btn)

	var info = Label.new()
	info.text = "Arrow keys: move | Click: plant | 1-4: select seed"
	info.position = Vector2(0, 620)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.6, 0.45))
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.25, 0.12)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	b.add_theme_font_size_override("font_size", 28)
	return b
