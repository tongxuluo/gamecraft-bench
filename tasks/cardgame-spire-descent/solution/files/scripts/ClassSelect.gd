extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.05, 0.10)
const COLOR_PANEL = Color(0.14, 0.12, 0.18)
const COLOR_ACCENT = Color(0.65, 0.45, 0.20)
const COLOR_TEXT = Color(0.92, 0.90, 0.85)

const CLASSES = [
	{"name": "Warrior", "color": Color(0.85, 0.35, 0.25), "desc": "Strength scaling\n80 HP\nStarter: 5 Strike, 4 Defend, 1 Bash"},
	{"name": "Rogue", "color": Color(0.30, 0.75, 0.40), "desc": "Shiv generation\n70 HP\nStarter: 5 Strike, 4 Defend, 2 Shiv"},
	{"name": "Mage", "color": Color(0.35, 0.45, 0.90), "desc": "Orb channelling\n60 HP\nStarter: 4 Strike, 4 Defend, 1 Zap, 1 Frost"},
]

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "CHOOSE YOUR CLASS"
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	for i in range(CLASSES.size()):
		var cls = CLASSES[i]
		var x_pos = 80 + i * 400
		var panel = ColorRect.new()
		panel.color = COLOR_PANEL
		panel.position = Vector2(x_pos, 130)
		panel.size = Vector2(360, 450)
		add_child(panel)

		var border = ColorRect.new()
		border.color = cls.color
		border.position = Vector2(x_pos, 130)
		border.size = Vector2(360, 4)
		add_child(border)

		# Portrait placeholder
		var portrait = ColorRect.new()
		portrait.color = cls.color * Color(0.6, 0.6, 0.6)
		portrait.position = Vector2(x_pos + 100, 160)
		portrait.size = Vector2(160, 160)
		add_child(portrait)
		var portrait_inner = ColorRect.new()
		portrait_inner.color = cls.color
		portrait_inner.position = Vector2(x_pos + 120, 180)
		portrait_inner.size = Vector2(120, 120)
		add_child(portrait_inner)

		var name_label = Label.new()
		name_label.text = cls.name
		name_label.position = Vector2(x_pos, 340)
		name_label.size = Vector2(360, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", cls.color)
		name_label.add_theme_font_size_override("font_size", 28)
		add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = cls.desc
		desc_label.position = Vector2(x_pos + 20, 385)
		desc_label.size = Vector2(320, 120)
		desc_label.add_theme_color_override("font_color", COLOR_TEXT)
		desc_label.add_theme_font_size_override("font_size", 16)
		add_child(desc_label)

		var btn = Button.new()
		btn.text = "SELECT"
		btn.position = Vector2(x_pos + 80, 520)
		btn.size = Vector2(200, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = cls.color * Color(0.4, 0.4, 0.4)
		sb.border_color = cls.color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT)
		btn.add_theme_font_size_override("font_size", 20)
		var class_name_str = cls.name
		btn.pressed.connect(func(): main.start_run(class_name_str))
		add_child(btn)
