extends Node2D

var main: Node = null
var level_index: int = 0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.12, 0.05)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "LEVEL COMPLETE!"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	title.position = Vector2(380, 200)
	add_child(title)

	var info = Label.new()
	info.text = "Level " + str(level_index + 1) + " solved!"
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	info.position = Vector2(520, 320)
	add_child(info)

	var next_btn = Button.new()
	next_btn.text = "Next Level"
	next_btn.position = Vector2(440, 440)
	next_btn.custom_minimum_size = Vector2(180, 50)
	next_btn.add_theme_font_size_override("font_size", 24)
	next_btn.pressed.connect(_on_next)
	add_child(next_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Level Select"
	menu_btn.position = Vector2(660, 440)
	menu_btn.custom_minimum_size = Vector2(180, 50)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)

func _on_next() -> void:
	if level_index < 4:
		main._enter_game(level_index + 1)
	else:
		main._enter_level_select()

func _on_menu() -> void:
	main._enter_level_select()
