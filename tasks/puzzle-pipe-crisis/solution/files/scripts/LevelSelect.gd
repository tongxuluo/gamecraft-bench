extends Node2D

var main: Node = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.06, 0.06, 0.1)
	add_child(bg)

	var title = Label.new()
	title.text = "SELECT LEVEL"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	title.position = Vector2(480, 40)
	add_child(title)

	var level_names = ["Level 1: Basic Routing", "Level 2: Color Match", "Level 3: Multi-Source"]
	var level_descs = [
		"Single source, single drain. Learn the basics.",
		"Two colored fluids must reach matching drains.",
		"Three sources, obstacles, tight timer."
	]

	for i in range(3):
		var panel = ColorRect.new()
		panel.size = Vector2(350, 150)
		panel.color = Color(0.12, 0.14, 0.18)
		panel.position = Vector2(80 + i * 400, 200)
		add_child(panel)

		var lbl = Label.new()
		lbl.text = level_names[i]
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
		lbl.position = Vector2(95 + i * 400, 215)
		add_child(lbl)

		var desc = Label.new()
		desc.text = level_descs[i]
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
		desc.position = Vector2(95 + i * 400, 260)
		add_child(desc)

		var btn = Button.new()
		btn.text = "PLAY"
		btn.position = Vector2(180 + i * 400, 310)
		btn.custom_minimum_size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_level.bind(i))
		add_child(btn)

	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(580, 600)
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_level(idx: int) -> void:
	main._enter_game(idx)

func _on_back() -> void:
	main._enter_title()
