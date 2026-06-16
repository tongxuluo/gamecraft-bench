extends Node2D

var main: Node = null
var won: bool = false

const COLOR_GOLD = Color(0.85, 0.70, 0.20)
const COLOR_PANEL = Color(0.08, 0.08, 0.10)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04) if not won else Color(0.02, 0.08, 0.04)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Result panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(290, 180)
	panel.size = Vector2(700, 360)
	add_child(panel)

	var border = ColorRect.new()
	border.color = COLOR_GOLD if won else Color(0.8, 0.2, 0.2)
	border.position = Vector2(288, 178)
	border.size = Vector2(704, 364)
	border.z_index = -1
	add_child(border)

	var title = Label.new()
	title.text = "VICTORY!" if won else "DEFEAT"
	title.position = Vector2(290, 210)
	title.size = Vector2(700, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD if won else Color(0.9, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	var msg = Label.new()
	if won:
		msg.text = "You beat all 3 blinds!\nFinal gold: $" + str(main.gold)
	else:
		msg.text = "Failed to meet the blind target.\nRound: " + str(main.round_num)
	msg.position = Vector2(290, 300)
	msg.size = Vector2(700, 80)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	msg.add_theme_font_size_override("font_size", 22)
	add_child(msg)

	# Jokers summary
	if main.jokers.size() > 0:
		var joker_lbl = Label.new()
		joker_lbl.text = "Jokers: " + str(main.jokers.size())
		joker_lbl.position = Vector2(290, 390)
		joker_lbl.size = Vector2(700, 40)
		joker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		joker_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
		joker_lbl.add_theme_font_size_override("font_size", 18)
		add_child(joker_lbl)

	# New Run button
	var btn = _make_button("NEW RUN", Vector2(490, 460))
	btn.pressed.connect(func():
		main.gold = 4
		main.round_num = 0
		main.jokers.clear()
		main._init_deck()
		main._enter_title()
	)
	add_child(btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_font_size_override("font_size", 28)
	return b
