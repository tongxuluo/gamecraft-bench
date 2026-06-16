extends Node2D

var main: Node = null

const COLOR_BG = Color(0.12, 0.10, 0.08)
const COLOR_WARM = Color(0.85, 0.65, 0.30)
const COLOR_PANEL = Color(0.20, 0.16, 0.12)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Warm accent bar (shop counter feel)
	var bar = ColorRect.new()
	bar.color = COLOR_WARM
	bar.position = Vector2(0, 340)
	bar.size = Vector2(1280, 4)
	add_child(bar)

	# Shop window decoration
	var window_frame = ColorRect.new()
	window_frame.color = Color(0.30, 0.24, 0.16)
	window_frame.position = Vector2(440, 80)
	window_frame.size = Vector2(400, 200)
	add_child(window_frame)

	var window_inner = ColorRect.new()
	window_inner.color = Color(0.15, 0.20, 0.30)
	window_inner.position = Vector2(450, 90)
	window_inner.size = Vector2(380, 180)
	add_child(window_inner)

	# Sword display in window
	var sword = ColorRect.new()
	sword.color = Color(0.70, 0.72, 0.75)
	sword.position = Vector2(620, 120)
	sword.size = Vector2(8, 120)
	add_child(sword)

	var hilt = ColorRect.new()
	hilt.color = COLOR_WARM
	hilt.position = Vector2(605, 220)
	hilt.size = Vector2(38, 12)
	add_child(hilt)

	var title = Label.new()
	title.text = "DUNGEON SHOP"
	title.position = Vector2(0, 300)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_WARM)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Shopkeeper Roguelike"
	subtitle.position = Vector2(0, 380)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	var start_btn = _make_button("OPEN SHOP", Vector2(490, 460))
	start_btn.pressed.connect(func(): main._enter_shop())
	add_child(start_btn)

	var info = Label.new()
	info.text = "Stock shelves. Set prices. Catch thieves. Survive 5 days."
	info.position = Vector2(0, 560)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_WARM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 28)
	return b
