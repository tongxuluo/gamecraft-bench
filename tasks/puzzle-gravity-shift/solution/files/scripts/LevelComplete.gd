extends Node2D

var main: Node = null
var level_index: int = 0

const COLOR_BG := Color(0.03, 0.08, 0.05)
const COLOR_ACCENT := Color(0.2, 0.9, 0.4)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var panel = ColorRect.new()
	panel.color = Color(0.08, 0.15, 0.10)
	panel.size = Vector2(600, 400)
	panel.position = Vector2(340, 160)
	add_child(panel)

	var border = ColorRect.new()
	border.color = COLOR_ACCENT
	border.size = Vector2(604, 404)
	border.position = Vector2(338, 158)
	add_child(border)
	# Re-add panel on top of border for inset effect
	var panel2 = ColorRect.new()
	panel2.color = Color(0.08, 0.15, 0.10)
	panel2.size = Vector2(600, 400)
	panel2.position = Vector2(340, 160)
	add_child(panel2)

	var title = Label.new()
	title.text = "CHAMBER COMPLETE!"
	title.position = Vector2(340, 200)
	title.size = Vector2(600, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(title)

	var info = Label.new()
	info.text = "Chamber %d cleared" % (level_index + 1)
	info.position = Vector2(340, 280)
	info.size = Vector2(600, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75))
	add_child(info)

	var total_levels: int = 5
	if level_index + 1 < total_levels:
		var next_btn = _make_button("NEXT CHAMBER", Vector2(440, 380))
		next_btn.pressed.connect(func(): main._enter_game(level_index + 1))
		add_child(next_btn)
	else:
		var win_label = Label.new()
		win_label.text = "All chambers complete! You mastered gravity!"
		win_label.position = Vector2(340, 360)
		win_label.size = Vector2(600, 40)
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.add_theme_font_size_override("font_size", 20)
		win_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.7))
		add_child(win_label)

	var menu_btn = _make_button("TITLE SCREEN", Vector2(440, 460))
	menu_btn.pressed.connect(func(): main._enter_title())
	add_child(menu_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(400, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.20, 0.15)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	b.add_theme_font_size_override("font_size", 26)
	return b
