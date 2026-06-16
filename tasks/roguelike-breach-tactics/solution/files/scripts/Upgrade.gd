extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.07, 0.10)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_ACCENT = Color(0.30, 0.65, 0.90)
const COLOR_TEXT = Color(0.90, 0.93, 0.96)

var upgrades = [
	{"name": "REINFORCED ARMOR", "desc": "+1 HP to all mechs", "color": Color(0.3, 0.6, 0.9)},
	{"name": "OVERCHARGE PUNCH", "desc": "Punch deals +1 damage", "color": Color(0.85, 0.5, 0.2)},
	{"name": "EXTENDED RANGE", "desc": "Artillery min range reduced to 1", "color": Color(0.7, 0.8, 0.3)},
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "MISSION COMPLETE - CHOOSE UPGRADE"
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Select one reactor core upgrade for your squad"
	subtitle.position = Vector2(0, 110)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	subtitle.add_theme_font_size_override("font_size", 20)
	add_child(subtitle)

	for i in range(upgrades.size()):
		var u = upgrades[i]
		var card = ColorRect.new()
		card.color = COLOR_PANEL
		card.position = Vector2(140 + i * 360, 200)
		card.size = Vector2(320, 300)
		add_child(card)

		var border = ColorRect.new()
		border.color = u.color
		border.position = card.position
		border.size = Vector2(320, 4)
		add_child(border)

		var icon = ColorRect.new()
		icon.color = u.color
		icon.position = card.position + Vector2(110, 40)
		icon.size = Vector2(100, 100)
		add_child(icon)

		var name_lbl = Label.new()
		name_lbl.text = u.name
		name_lbl.position = card.position + Vector2(10, 160)
		name_lbl.size = Vector2(300, 30)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 22)
		add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = u.desc
		desc_lbl.position = card.position + Vector2(10, 200)
		desc_lbl.size = Vector2(300, 40)
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		desc_lbl.add_theme_font_size_override("font_size", 16)
		add_child(desc_lbl)

		var btn = Button.new()
		btn.text = "SELECT"
		btn.position = card.position + Vector2(80, 250)
		btn.size = Vector2(160, 40)
		var sb = StyleBoxFlat.new()
		sb.bg_color = u.color * Color(0.4, 0.4, 0.4)
		sb.border_color = u.color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb.duplicate())
		btn.add_theme_stylebox_override("pressed", sb.duplicate())
		btn.add_theme_color_override("font_color", COLOR_TEXT)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _select_upgrade())
		add_child(btn)

	# Continue button at bottom
	var cont_btn = _make_button("NEXT MISSION", Vector2(540, 580))
	cont_btn.pressed.connect(func(): main._enter_battle())
	add_child(cont_btn)

func _select_upgrade() -> void:
	# In oracle, just proceed
	main._enter_battle()

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb.duplicate())
	b.add_theme_stylebox_override("pressed", sb.duplicate())
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 20)
	return b
