extends Node2D

var main: Node = null

const COLOR_BG = Color(0.05, 0.02, 0.02)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_DANGER = Color(0.9, 0.2, 0.2)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Debris particles
	var rng = RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(30):
		var debris = ColorRect.new()
		debris.color = Color(0.4, 0.2, 0.1, rng.randf_range(0.3, 0.7))
		debris.size = Vector2(rng.randi_range(3, 12), rng.randi_range(3, 8))
		debris.position = Vector2(rng.randi_range(300, 980), rng.randi_range(200, 500))
		debris.rotation = rng.randf_range(0, 3.14)
		add_child(debris)

	var title = Label.new()
	title.text = "SHIP DESTROYED"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_DANGER)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var sub = Label.new()
	sub.text = "Your voyage has ended.\nThe crew did not survive."
	sub.position = Vector2(0, 280)
	sub.size = Vector2(1280, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 24)
	add_child(sub)

	var stats = Label.new()
	stats.text = "Reached sector: " + str(main.sector) + "\nScrap collected: " + str(main.scrap)
	stats.position = Vector2(0, 400)
	stats.size = Vector2(1280, 80)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	stats.add_theme_font_size_override("font_size", 20)
	add_child(stats)

	var btn = Button.new()
	btn.text = "TRY AGAIN"
	btn.position = Vector2(540, 550)
	btn.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.12)
	sb.border_color = COLOR_DANGER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func():
		main._init_game_state()
		main.fuel = 14
		main.scrap = 30
		main.hull = 30
		main.sector = 1
		main.sector_map = []
		main._enter_title()
	)
	add_child(btn)
