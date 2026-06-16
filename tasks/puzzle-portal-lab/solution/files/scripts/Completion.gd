extends Node2D

var main: Node = null
var chamber_index: int = 0

const COLOR_BG := Color(0.92, 0.94, 0.96)
const COLOR_DARK := Color(0.12, 0.14, 0.18)
const COLOR_GREEN := Color(0.15, 0.75, 0.3)
const COLOR_BLUE := Color(0.15, 0.45, 0.95)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Success panel
	var panel = ColorRect.new()
	panel.color = Color(0.98, 0.99, 0.98)
	panel.position = Vector2(340, 160)
	panel.size = Vector2(600, 400)
	add_child(panel)

	var border = ColorRect.new()
	border.color = COLOR_GREEN
	border.position = Vector2(337, 157)
	border.size = Vector2(606, 406)
	border.z_index = -1
	add_child(border)

	# Checkmark area
	var check_bg = ColorRect.new()
	check_bg.color = COLOR_GREEN
	check_bg.position = Vector2(590, 200)
	check_bg.size = Vector2(100, 100)
	add_child(check_bg)

	var check_label = Label.new()
	check_label.text = "OK"
	check_label.position = Vector2(590, 210)
	check_label.size = Vector2(100, 80)
	check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check_label.add_theme_color_override("font_color", Color(1, 1, 1))
	check_label.add_theme_font_size_override("font_size", 48)
	add_child(check_label)

	# Title
	var title = Label.new()
	title.text = "CHAMBER %02d COMPLETE" % (chamber_index + 1)
	title.position = Vector2(0, 320)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_DARK)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Test subject has demonstrated adequate spatial reasoning."
	sub.position = Vector2(0, 370)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
	sub.add_theme_font_size_override("font_size", 18)
	add_child(sub)

	# Next chamber button
	var has_next = chamber_index < 2
	if has_next:
		var next_btn = _make_button("NEXT CHAMBER", Vector2(390, 440))
		next_btn.pressed.connect(func(): main._enter_game(chamber_index + 1))
		add_child(next_btn)

	# Return button
	var ret_btn = _make_button("CHAMBER SELECT", Vector2(390, 510))
	ret_btn.pressed.connect(func(): main._enter_chamber_select())
	add_child(ret_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(500, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_DARK
	sb.border_color = COLOR_BLUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	b.add_theme_font_size_override("font_size", 22)
	return b
