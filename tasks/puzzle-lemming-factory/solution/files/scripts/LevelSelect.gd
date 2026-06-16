extends Node2D

var main: Node = null

const COLOR_BG := Color(0.10, 0.07, 0.05)
const COLOR_ACCENT := Color(0.85, 0.55, 0.15)
const COLOR_PANEL := Color(0.20, 0.14, 0.10)
const COLOR_TEXT := Color(0.95, 0.90, 0.80)

const LEVELS := [
	{"name": "First Steps", "quota": 5, "total": 10, "desc": "Learn to dig."},
	{"name": "Bridge the Gap", "quota": 7, "total": 12, "desc": "Build across the chasm."},
	{"name": "Factory Floor", "quota": 8, "total": 15, "desc": "Use all your skills."},
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var header = Label.new()
	header.text = "SELECT LEVEL"
	header.position = Vector2(0, 30)
	header.size = Vector2(1280, 60)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_theme_font_size_override("font_size", 40)
	add_child(header)

	for i in range(LEVELS.size()):
		var lvl = LEVELS[i]
		var panel = ColorRect.new()
		panel.color = COLOR_PANEL
		panel.position = Vector2(200, 120 + i * 180)
		panel.size = Vector2(880, 150)
		add_child(panel)

		var border = ColorRect.new()
		border.color = COLOR_ACCENT
		border.position = Vector2(200, 120 + i * 180)
		border.size = Vector2(880, 3)
		add_child(border)

		var name_lbl = Label.new()
		name_lbl.text = "Level %d: %s" % [i + 1, lvl.name]
		name_lbl.position = Vector2(230, 135 + i * 180)
		name_lbl.size = Vector2(400, 40)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 26)
		add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = "%s\nQuota: %d / %d creatures" % [lvl.desc, lvl.quota, lvl.total]
		desc_lbl.position = Vector2(230, 175 + i * 180)
		desc_lbl.size = Vector2(500, 60)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		desc_lbl.add_theme_font_size_override("font_size", 18)
		add_child(desc_lbl)

		var btn = Button.new()
		btn.text = "PLAY"
		btn.position = Vector2(850, 160 + i * 180)
		btn.size = Vector2(180, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_ACCENT
		sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", Color(0.05, 0.03, 0.02))
		btn.add_theme_font_size_override("font_size", 22)
		var lvl_id = i + 1
		btn.pressed.connect(func(): main._enter_game(lvl_id))
		add_child(btn)

	var back_btn = Button.new()
	back_btn.text = "< BACK"
	back_btn.position = Vector2(30, 660)
	back_btn.size = Vector2(140, 40)
	back_btn.add_theme_color_override("font_color", COLOR_ACCENT)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func(): main._enter_title())
	add_child(back_btn)
