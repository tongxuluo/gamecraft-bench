extends Node2D

var main: Node = null

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "RULE REWRITE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	title.position = Vector2(400, 180)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Push words. Rewrite rules. Solve puzzles."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	sub.position = Vector2(400, 280)
	add_child(sub)

	# Start button
	var btn = Button.new()
	btn.text = "START"
	btn.position = Vector2(560, 400)
	btn.custom_minimum_size = Vector2(160, 50)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_start)
	add_child(btn)

	# Controls info
	var info = Label.new()
	info.text = "Arrow Keys: Move | Z: Undo | R: Reset"
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.position = Vector2(420, 550)
	add_child(info)

func _on_start() -> void:
	main._enter_level_select()
