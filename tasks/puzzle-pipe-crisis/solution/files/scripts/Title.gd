extends Node2D

var main: Node = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	# Title text
	var title = Label.new()
	title.text = "PIPE CRISIS"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	title.position = Vector2(400, 120)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Route the fluid. Beat the clock."
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.6, 0.7, 0.65))
	sub.position = Vector2(440, 220)
	add_child(sub)

	# Decorative pipes (visual flair)
	for i in range(5):
		var pipe_dec = ColorRect.new()
		pipe_dec.size = Vector2(60, 12)
		pipe_dec.color = Color(0.3, 0.35, 0.4)
		pipe_dec.position = Vector2(200 + i * 160, 300)
		add_child(pipe_dec)
		var joint = ColorRect.new()
		joint.size = Vector2(12, 40)
		joint.color = Color(0.4, 0.45, 0.5)
		joint.position = Vector2(254 + i * 160, 286)
		add_child(joint)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "START GAME"
	start_btn.position = Vector2(520, 420)
	start_btn.custom_minimum_size = Vector2(240, 60)
	start_btn.add_theme_font_size_override("font_size", 28)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	# Level Select button
	var select_btn = Button.new()
	select_btn.text = "LEVEL SELECT"
	select_btn.position = Vector2(520, 510)
	select_btn.custom_minimum_size = Vector2(240, 60)
	select_btn.add_theme_font_size_override("font_size", 28)
	select_btn.pressed.connect(_on_level_select)
	add_child(select_btn)

	# Instructions
	var instr = Label.new()
	instr.text = "Click to place pipes | R or Right-click to rotate | Route fluid before time runs out!"
	instr.add_theme_font_size_override("font_size", 16)
	instr.add_theme_color_override("font_color", Color(0.5, 0.55, 0.5))
	instr.position = Vector2(280, 640)
	add_child(instr)

func _on_start() -> void:
	main._enter_game(0)

func _on_level_select() -> void:
	main._enter_level_select()
