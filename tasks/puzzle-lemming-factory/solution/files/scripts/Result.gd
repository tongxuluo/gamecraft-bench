extends Node2D

var main: Node = null
var level_id: int = 1
var won: bool = false
var saved_count: int = 0
var quota: int = 5

const COLOR_BG := Color(0.08, 0.06, 0.04)
const COLOR_WIN := Color(0.2, 0.8, 0.3)
const COLOR_LOSE := Color(0.9, 0.3, 0.2)
const COLOR_ACCENT := Color(0.85, 0.55, 0.15)
const COLOR_PANEL := Color(0.20, 0.14, 0.10)
const COLOR_TEXT := Color(0.95, 0.90, 0.80)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Result panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(290, 150)
	panel.size = Vector2(700, 420)
	add_child(panel)

	var border = ColorRect.new()
	border.color = COLOR_WIN if won else COLOR_LOSE
	border.position = Vector2(290, 150)
	border.size = Vector2(700, 4)
	add_child(border)

	# Title
	var title = Label.new()
	title.text = "LEVEL COMPLETE!" if won else "LEVEL FAILED"
	title.position = Vector2(290, 180)
	title.size = Vector2(700, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_WIN if won else COLOR_LOSE)
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)

	# Stats
	var pct = 0
	if quota > 0:
		pct = int(float(saved_count) / float(quota) * 100.0)
	var stats = Label.new()
	stats.text = "Creatures Saved: %d\nQuota Required: %d\nSave Rate: %d%%" % [saved_count, quota, pct]
	stats.position = Vector2(440, 270)
	stats.size = Vector2(400, 120)
	stats.add_theme_color_override("font_color", COLOR_TEXT)
	stats.add_theme_font_size_override("font_size", 24)
	add_child(stats)

	# Star rating
	var stars = 0
	if won:
		stars = 1
		if saved_count >= quota + 2:
			stars = 2
		if saved_count >= quota + 4:
			stars = 3
	var star_lbl = Label.new()
	var star_text = ""
	for i in range(3):
		star_text += "[*]" if i < stars else "[ ]"
		star_text += " "
	star_lbl.text = star_text
	star_lbl.position = Vector2(440, 400)
	star_lbl.size = Vector2(400, 40)
	star_lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	star_lbl.add_theme_font_size_override("font_size", 32)
	add_child(star_lbl)

	# Buttons
	var retry_btn = _make_button("RETRY", Vector2(380, 470))
	retry_btn.pressed.connect(func(): main._enter_game(level_id))
	add_child(retry_btn)

	if won and level_id < 3:
		var next_btn = _make_button("NEXT LEVEL", Vector2(620, 470))
		next_btn.pressed.connect(func(): main._enter_game(level_id + 1))
		add_child(next_btn)

	var menu_btn = _make_button("LEVEL SELECT", Vector2(500, 530))
	menu_btn.pressed.connect(func(): main._enter_level_select())
	add_child(menu_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(220, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b
