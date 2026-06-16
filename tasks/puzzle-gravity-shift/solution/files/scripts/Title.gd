extends Node2D

var main: Node = null

const COLOR_BG_TOP := Color(0.05, 0.05, 0.12)
const COLOR_BG_BOT := Color(0.02, 0.02, 0.06)
const COLOR_ACCENT := Color(0.3, 0.7, 0.9)
const COLOR_PANEL := Color(0.12, 0.14, 0.20)

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

	# Decorative arrows
	_draw_arrow(Vector2(200, 200), 0)
	_draw_arrow(Vector2(1080, 200), 90)
	_draw_arrow(Vector2(200, 500), 270)
	_draw_arrow(Vector2(1080, 500), 180)

	var title = Label.new()
	title.text = "GRAVITY SHIFT"
	title.position = Vector2(0, 120)
	title.size = Vector2(1280, 120)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Rotate gravity. Guide the ball. Escape the chamber."
	subtitle.position = Vector2(0, 240)
	subtitle.size = Vector2(1280, 60)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	var play_btn = _make_button("PLAY", Vector2(490, 420))
	play_btn.pressed.connect(func(): main._enter_game(0))
	add_child(play_btn)

	var level_label = Label.new()
	level_label.text = "Arrow Keys = Rotate Gravity | Z = Undo | R = Restart"
	level_label.position = Vector2(0, 620)
	level_label.size = Vector2(1280, 40)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	level_label.add_theme_font_size_override("font_size", 18)
	add_child(level_label)

func _draw_arrow(pos: Vector2, angle_deg: float) -> void:
	var arrow = ColorRect.new()
	arrow.color = COLOR_ACCENT * Color(1, 1, 1, 0.3)
	arrow.size = Vector2(40, 80)
	arrow.position = pos - Vector2(20, 40)
	arrow.rotation_degrees = angle_deg
	arrow.pivot_offset = Vector2(20, 40)
	add_child(arrow)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 70)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	b.add_theme_font_size_override("font_size", 32)
	return b
