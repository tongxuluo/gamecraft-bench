extends Node2D

var main: Node = null

const LEVELS := [
	{"name": "Tower Up", "desc": "Build a tower to reach the pipe above.", "goo_types": "Standard + Rigid"},
	{"name": "Bridge Gap", "desc": "Bridge the chasm to reach the far side.", "goo_types": "Standard + Rigid + Balloon"},
	{"name": "Wind Challenge", "desc": "Build against the wind with balloon goo.", "goo_types": "All types"},
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.10, 0.14, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "SELECT LEVEL"
	title.position = Vector2(0, 30)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.30, 0.85, 0.25))
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)

	for i in range(LEVELS.size()):
		var panel = _make_level_panel(i, LEVELS[i])
		panel.position = Vector2(140, 120 + i * 190)
		add_child(panel)

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(560, 650)
	back_btn.size = Vector2(160, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.20, 0.15)
	sb.border_color = Color(0.5, 0.45, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	back_btn.add_theme_stylebox_override("normal", sb)
	back_btn.add_theme_stylebox_override("hover", sb)
	back_btn.add_theme_stylebox_override("pressed", sb)
	back_btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func(): main._enter_title())
	add_child(back_btn)

func _make_level_panel(idx: int, data: Dictionary) -> Control:
	var panel = Control.new()
	panel.size = Vector2(1000, 170)

	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.22, 0.12)
	bg.size = Vector2(1000, 170)
	panel.add_child(bg)

	var border = ColorRect.new()
	border.color = Color(0.35, 0.65, 0.30)
	border.position = Vector2(0, 0)
	border.size = Vector2(1000, 3)
	panel.add_child(border)

	var lbl_name = Label.new()
	lbl_name.text = "Level %d: %s" % [idx + 1, data["name"]]
	lbl_name.position = Vector2(20, 15)
	lbl_name.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	lbl_name.add_theme_font_size_override("font_size", 30)
	panel.add_child(lbl_name)

	var lbl_desc = Label.new()
	lbl_desc.text = data["desc"]
	lbl_desc.position = Vector2(20, 60)
	lbl_desc.add_theme_color_override("font_color", Color(0.7, 0.78, 0.65))
	lbl_desc.add_theme_font_size_override("font_size", 20)
	panel.add_child(lbl_desc)

	var lbl_types = Label.new()
	lbl_types.text = "Goo: " + data["goo_types"]
	lbl_types.position = Vector2(20, 95)
	lbl_types.add_theme_color_override("font_color", Color(0.6, 0.7, 0.55))
	lbl_types.add_theme_font_size_override("font_size", 18)
	panel.add_child(lbl_types)

	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(830, 55)
	play_btn.size = Vector2(140, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.45, 0.18)
	sb.border_color = Color(0.40, 0.75, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	play_btn.add_theme_stylebox_override("normal", sb)
	play_btn.add_theme_stylebox_override("hover", sb)
	play_btn.add_theme_stylebox_override("pressed", sb)
	play_btn.add_theme_color_override("font_color", Color(0.95, 1.0, 0.9))
	play_btn.add_theme_font_size_override("font_size", 24)
	var level_i = idx
	play_btn.pressed.connect(func(): main._enter_game(level_i))
	panel.add_child(play_btn)

	return panel
