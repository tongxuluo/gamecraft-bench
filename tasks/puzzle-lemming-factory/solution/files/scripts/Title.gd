extends Node2D

var main: Node = null

const COLOR_BG_TOP := Color(0.12, 0.08, 0.06)
const COLOR_BG_BOT := Color(0.06, 0.04, 0.03)
const COLOR_ACCENT := Color(0.85, 0.55, 0.15)
const COLOR_PANEL := Color(0.20, 0.14, 0.10)
const COLOR_TEXT := Color(0.95, 0.90, 0.80)

var _silhouettes: Array = []
var _time: float = 0.0

func _ready() -> void:
	# Background
	var bg_top = ColorRect.new()
	bg_top.color = COLOR_BG_TOP
	bg_top.size = Vector2(1280, 400)
	add_child(bg_top)
	var bg_bot = ColorRect.new()
	bg_bot.color = COLOR_BG_BOT
	bg_bot.position = Vector2(0, 400)
	bg_bot.size = Vector2(1280, 320)
	add_child(bg_bot)

	# Factory floor line
	var floor_line = ColorRect.new()
	floor_line.color = COLOR_ACCENT
	floor_line.position = Vector2(0, 398)
	floor_line.size = Vector2(1280, 4)
	add_child(floor_line)

	# Gear decorations
	for i in range(3):
		var gear = _make_gear(Vector2(200 + i * 400, 180), 40 + i * 10)
		add_child(gear)

	# Title
	var title = Label.new()
	title.text = "LEMMING\nFACTORY"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 260)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Guide the workers. Save the quota."
	sub.position = Vector2(0, 320)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_ACCENT)
	sub.add_theme_font_size_override("font_size", 22)
	add_child(sub)

	# Buttons
	var start_btn = _make_button("START", Vector2(490, 450))
	start_btn.pressed.connect(func(): main._enter_level_select())
	add_child(start_btn)

	# Marching silhouettes at bottom
	for i in range(8):
		var s = ColorRect.new()
		s.color = Color(0.3, 0.2, 0.1, 0.6)
		s.size = Vector2(16, 24)
		s.position = Vector2(-50 + i * 60, 620)
		add_child(s)
		_silhouettes.append(s)

func _process(delta: float) -> void:
	_time += delta
	for i in range(_silhouettes.size()):
		var s: ColorRect = _silhouettes[i]
		s.position.x += 40.0 * delta
		if s.position.x > 1330:
			s.position.x = -50
		# Bob up and down
		s.position.y = 620 + sin(_time * 3.0 + i) * 4.0

func _make_gear(pos: Vector2, radius: float) -> Node2D:
	var gear = Node2D.new()
	gear.position = pos
	# Simple gear representation with colored rect
	var center = ColorRect.new()
	center.color = Color(0.3, 0.22, 0.12, 0.4)
	center.size = Vector2(radius, radius)
	center.position = Vector2(-radius / 2, -radius / 2)
	gear.add_child(center)
	return gear

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 30)
	return b
