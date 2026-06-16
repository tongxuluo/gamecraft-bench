extends Node2D

var main: Node = null
var level_index: int = 0
var blobs_saved: int = 0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.06)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Victory banner
	var banner = ColorRect.new()
	banner.color = Color(0.20, 0.45, 0.15)
	banner.position = Vector2(290, 120)
	banner.size = Vector2(700, 100)
	add_child(banner)

	var title = Label.new()
	title.text = "LEVEL COMPLETE!"
	title.position = Vector2(0, 135)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.20))
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)

	# Stats
	var stats = Label.new()
	stats.text = "Blobs Saved: %d" % blobs_saved
	stats.position = Vector2(0, 280)
	stats.size = Vector2(1280, 40)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75))
	stats.add_theme_font_size_override("font_size", 30)
	add_child(stats)

	var level_lbl = Label.new()
	level_lbl.text = "Level %d" % (level_index + 1)
	level_lbl.position = Vector2(0, 330)
	level_lbl.size = Vector2(1280, 40)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.55))
	level_lbl.add_theme_font_size_override("font_size", 22)
	add_child(level_lbl)

	# Next level button
	if level_index < 2:
		var next_btn = _make_button("NEXT LEVEL", Vector2(490, 430))
		next_btn.pressed.connect(func(): main._enter_game(level_index + 1))
		add_child(next_btn)

	# Level select button
	var select_btn = _make_button("LEVEL SELECT", Vector2(490, 520))
	select_btn.pressed.connect(func(): main._enter_level_select())
	add_child(select_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 65)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.30, 0.15)
	sb.border_color = Color(0.40, 0.75, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.92, 0.96, 0.88))
	b.add_theme_font_size_override("font_size", 26)
	return b
