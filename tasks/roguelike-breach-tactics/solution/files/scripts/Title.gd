extends Node2D

var main: Node = null

const COLOR_BG_TOP = Color(0.06, 0.08, 0.12)
const COLOR_BG_BOT = Color(0.03, 0.04, 0.06)
const COLOR_ACCENT = Color(0.30, 0.65, 0.90)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)

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
	var stripe = ColorRect.new()
	stripe.color = COLOR_ACCENT
	stripe.position = Vector2(0, 358)
	stripe.size = Vector2(1280, 4)
	add_child(stripe)

	# Mech silhouettes (simple colored rects)
	for i in range(3):
		var mech = ColorRect.new()
		mech.color = Color(0.20, 0.45, 0.70, 0.6)
		mech.size = Vector2(60, 80)
		mech.position = Vector2(440 + i * 140, 200)
		add_child(mech)
		var head = ColorRect.new()
		head.color = Color(0.30, 0.60, 0.85, 0.7)
		head.size = Vector2(30, 30)
		head.position = Vector2(455 + i * 140, 175)
		add_child(head)

	var title = Label.new()
	title.text = "BREACH TACTICS"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.90, 0.93, 0.96))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Defend the city. Control the grid."
	subtitle.position = Vector2(0, 150)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	var start_btn = _make_button("START MISSION", Vector2(490, 440))
	start_btn.pressed.connect(func(): main._enter_battle())
	add_child(start_btn)

	var quit_btn = _make_button("QUIT", Vector2(490, 530))
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
	b.add_theme_stylebox_override("hover", sb.duplicate())
	b.add_theme_stylebox_override("pressed", sb.duplicate())
	b.add_theme_color_override("font_color", Color(0.90, 0.93, 0.96))
	b.add_theme_font_size_override("font_size", 26)
	return b
