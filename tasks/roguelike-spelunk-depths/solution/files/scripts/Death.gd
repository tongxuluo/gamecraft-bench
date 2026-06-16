extends Node2D

var main: Node = null

const COLOR_DIM = Color(0, 0, 0, 0.75)
const COLOR_PANEL = Color(0.15, 0.12, 0.08)
const COLOR_ACCENT = Color(0.85, 0.65, 0.25)
const COLOR_RED = Color(0.85, 0.3, 0.3)

func _ready() -> void:
	var dim = ColorRect.new()
	dim.color = COLOR_DIM
	dim.size = Vector2(1280, 720)
	add_child(dim)

	var won = main.floor_num > main.max_floors
	var accent = COLOR_ACCENT if won else COLOR_RED

	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(340, 160)
	panel.size = Vector2(600, 400)
	add_child(panel)
	var bar = ColorRect.new()
	bar.color = accent
	bar.position = Vector2(340, 160)
	bar.size = Vector2(600, 6)
	add_child(bar)

	var msg = Label.new()
	msg.text = "ESCAPED!" if won else "PERISHED"
	msg.position = Vector2(340, 190)
	msg.size = Vector2(600, 80)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", accent)
	msg.add_theme_font_size_override("font_size", 52)
	add_child(msg)

	var stats = Label.new()
	stats.text = "Depth reached: Floor %d\nGold collected: %d\nEnemies defeated: %d" % [
		main.floor_num - 1 if not won else main.max_floors,
		main.gold,
		main.enemies_killed
	]
	stats.position = Vector2(340, 300)
	stats.size = Vector2(600, 120)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	stats.add_theme_font_size_override("font_size", 22)
	add_child(stats)

	var sub = Label.new()
	sub.text = "You made it out alive!" if won else "Death is permanent. Knowledge remains."
	sub.position = Vector2(340, 420)
	sub.size = Vector2(600, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	sub.add_theme_font_size_override("font_size", 18)
	add_child(sub)

	var retry = _make_btn("NEW RUN", Vector2(400, 490))
	retry.pressed.connect(func(): _restart())
	add_child(retry)

	var title_btn = _make_btn("TITLE", Vector2(660, 490))
	title_btn.pressed.connect(func(): main._enter_title())
	add_child(title_btn)

func _restart() -> void:
	main.reset_run()
	main._enter_cave()

func _make_btn(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.06)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	b.add_theme_font_size_override("font_size", 24)
	return b
