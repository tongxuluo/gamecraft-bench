extends Node2D

var main: Node = null
var won: bool = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	if won:
		bg.color = Color(0.05, 0.12, 0.05)
	else:
		bg.color = Color(0.12, 0.05, 0.05)
	add_child(bg)

	var title = Label.new()
	if won:
		title.text = "VICTORY!"
		title.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		title.text = "DEFEATED"
		title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_font_size_override("font_size", 64)
	title.position = Vector2(440, 200)
	add_child(title)

	var sub = Label.new()
	if won:
		sub.text = "The dragon falls! Your words proved mightier than its flame."
	else:
		sub.text = "Your vocabulary was not enough this time..."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	sub.position = Vector2(300, 320)
	add_child(sub)

	var btn = Button.new()
	btn.text = "RETURN TO TITLE"
	btn.position = Vector2(490, 480)
	btn.custom_minimum_size = Vector2(300, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(Callable(self, "_on_return"))
	add_child(btn)

func _on_return() -> void:
	main._enter_title()
