extends Control

var main: Node = null

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.15)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Title label
	var title = Label.new()
	title.text = "DICE THRONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(340, 150)
	title.size = Vector2(600, 80)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "A Dice-Rolling Roguelike"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	sub.position = Vector2(440, 240)
	sub.size = Vector2(400, 40)
	add_child(sub)

	# Dice decoration
	for i in range(5):
		var die_rect = ColorRect.new()
		die_rect.color = Color(0.9, 0.9, 0.95)
		die_rect.size = Vector2(60, 60)
		die_rect.position = Vector2(340 + i * 130, 320)
		add_child(die_rect)
		var face_label = Label.new()
		var faces = ["S", "S", "H", "K", "B"]
		face_label.text = faces[i]
		face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_label.add_theme_font_size_override("font_size", 32)
		face_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.2))
		face_label.position = Vector2(340 + i * 130 + 10, 330)
		face_label.size = Vector2(40, 50)
		add_child(face_label)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "START ADVENTURE"
	start_btn.position = Vector2(490, 460)
	start_btn.size = Vector2(300, 60)
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_on_start)
	start_btn.name = "StartBtn"
	add_child(start_btn)

	# Instructions
	var instr = Label.new()
	instr.text = "Roll dice. Lock keepers. Reroll the rest. Defeat the dungeon!"
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_size_override("font_size", 16)
	instr.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	instr.position = Vector2(290, 560)
	instr.size = Vector2(700, 30)
	add_child(instr)

func _on_start() -> void:
	main._enter_combat()
