extends Node2D

var main: Node = null
var floor_num: int = 1
var turns: int = 0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.02, 0.02)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "YOU HAVE FALLEN"
	title.position = Vector2(0, 120)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	var stats = Label.new()
	stats.text = "Floor Reached: %d\nTurns Taken: %d\nDeepest Floor: %d" % [floor_num, turns, main.deepest_floor]
	stats.position = Vector2(0, 260)
	stats.size = Vector2(1280, 120)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	stats.add_theme_font_size_override("font_size", 28)
	add_child(stats)

	var retry_btn = _make_button("RETRY FLOOR", Vector2(390, 440))
	retry_btn.pressed.connect(func(): main._enter_game(floor_num))
	add_child(retry_btn)

	var menu_btn = _make_button("RETURN TO TITLE", Vector2(390, 530))
	menu_btn.pressed.connect(func(): main._enter_title())
	add_child(menu_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(500, 65)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.08, 0.08)
	sb.border_color = Color(0.8, 0.3, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	b.add_theme_font_size_override("font_size", 26)
	return b
