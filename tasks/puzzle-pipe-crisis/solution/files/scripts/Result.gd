extends Node2D

var main: Node = null
var level_index: int = 0
var won: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.05, 0.06, 0.08)
	add_child(bg)

	var title = Label.new()
	if won:
		title.text = "LEVEL COMPLETE!"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		title.text = "SYSTEM OVERFLOW!"
		title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	title.add_theme_font_size_override("font_size", 56)
	title.position = Vector2(350, 200)
	add_child(title)

	var info = Label.new()
	info.text = "Level " + str(level_index + 1)
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	info.position = Vector2(580, 300)
	add_child(info)

	var retry_btn = Button.new()
	retry_btn.text = "RETRY"
	retry_btn.position = Vector2(440, 450)
	retry_btn.custom_minimum_size = Vector2(160, 50)
	retry_btn.add_theme_font_size_override("font_size", 24)
	retry_btn.pressed.connect(_on_retry)
	add_child(retry_btn)

	var menu_btn = Button.new()
	menu_btn.text = "MENU"
	menu_btn.position = Vector2(680, 450)
	menu_btn.custom_minimum_size = Vector2(160, 50)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.pressed.connect(_on_menu)
	add_child(menu_btn)

	if won and level_index < 2:
		var next_btn = Button.new()
		next_btn.text = "NEXT LEVEL"
		next_btn.position = Vector2(540, 540)
		next_btn.custom_minimum_size = Vector2(200, 50)
		next_btn.add_theme_font_size_override("font_size", 24)
		next_btn.pressed.connect(_on_next)
		add_child(next_btn)

func _on_retry() -> void:
	main._enter_game(level_index)

func _on_menu() -> void:
	main._enter_title()

func _on_next() -> void:
	main._enter_game(level_index + 1)
