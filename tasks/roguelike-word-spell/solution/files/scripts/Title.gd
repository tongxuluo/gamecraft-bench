extends Node2D

var main: Node = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.15)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "WORD SPELL"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	title.position = Vector2(400, 150)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Cast words. Slay monsters."
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	sub.position = Vector2(460, 260)
	add_child(sub)

	# Decorative letter tiles
	var letters = ["W", "O", "R", "D"]
	for i in range(letters.size()):
		var tile = _make_tile(letters[i], Vector2(420 + i * 100, 340))
		add_child(tile)

	# Start button
	var btn = _make_button("START GAME", Vector2(490, 500), Callable(self, "_on_start"))
	add_child(btn)

func _make_tile(letter: String, pos: Vector2) -> ColorRect:
	var tile = ColorRect.new()
	tile.color = Color(0.2, 0.15, 0.35)
	tile.size = Vector2(70, 70)
	tile.position = pos
	var lbl = Label.new()
	lbl.text = letter
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.position = Vector2(20, 10)
	tile.add_child(lbl)
	return tile

func _make_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(300, 60)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(callback)
	return btn

func _on_start() -> void:
	main.fight_index = 0
	main.player_hp = 100
	main._init_letter_pool()
	main._enter_combat()
