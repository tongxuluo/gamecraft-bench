extends Node2D

var main: Node = null

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "SELECT LEVEL"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(490, 60)
	add_child(title)

	var level_names = ["1: First Steps", "2: Push It", "3: Who Am I?", "4: Deadly Path", "5: Chain Reaction"]
	for i in range(level_names.size()):
		var btn = Button.new()
		btn.text = level_names[i]
		btn.position = Vector2(460, 150 + i * 80)
		btn.custom_minimum_size = Vector2(360, 55)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_level.bind(i))
		add_child(btn)

	var back = Button.new()
	back.text = "Back"
	back.position = Vector2(560, 620)
	back.custom_minimum_size = Vector2(160, 45)
	back.pressed.connect(_on_back)
	add_child(back)

func _on_level(idx: int) -> void:
	main._enter_game(idx)

func _on_back() -> void:
	main._enter_title()
