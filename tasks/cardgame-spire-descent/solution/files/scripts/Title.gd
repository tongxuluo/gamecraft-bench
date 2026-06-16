extends Node2D

var main: Node = null

const COLOR_BG_TOP = Color(0.08, 0.06, 0.12)
const COLOR_BG_BOT = Color(0.03, 0.02, 0.06)
const COLOR_PANEL = Color(0.14, 0.12, 0.18)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)

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

	# Tower silhouette (simple rectangles)
	var tower_base = ColorRect.new()
	tower_base.color = Color(0.05, 0.04, 0.08)
	tower_base.position = Vector2(540, 80)
	tower_base.size = Vector2(200, 280)
	add_child(tower_base)
	var tower_top = ColorRect.new()
	tower_top.color = Color(0.05, 0.04, 0.08)
	tower_top.position = Vector2(580, 30)
	tower_top.size = Vector2(120, 60)
	add_child(tower_top)
	var tower_spire = ColorRect.new()
	tower_spire.color = Color(0.05, 0.04, 0.08)
	tower_spire.position = Vector2(620, 10)
	tower_spire.size = Vector2(40, 30)
	add_child(tower_spire)

	# Lightning accents
	for i in range(3):
		var bolt = ColorRect.new()
		bolt.color = Color(0.80, 0.70, 0.30, 0.6)
		bolt.position = Vector2(350 + i * 200, 60 + i * 40)
		bolt.size = Vector2(3, 80)
		bolt.rotation = 0.2 - i * 0.15
		add_child(bolt)

	var stripe = ColorRect.new()
	stripe.color = COLOR_ACCENT
	stripe.position = Vector2(0, 358)
	stripe.size = Vector2(1280, 4)
	add_child(stripe)

	var title = Label.new()
	title.text = "SPIRE DESCENT"
	title.position = Vector2(0, 380)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "A Deckbuilder Roguelike"
	subtitle.position = Vector2(0, 440)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	subtitle.add_theme_font_size_override("font_size", 20)
	add_child(subtitle)

	var start_btn = _make_button("NEW RUN", Vector2(490, 520))
	start_btn.pressed.connect(func(): main._enter_class_select())
	add_child(start_btn)

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
