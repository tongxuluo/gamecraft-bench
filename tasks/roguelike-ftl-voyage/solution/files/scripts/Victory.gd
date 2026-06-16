extends Node2D

var main: Node = null

const COLOR_BG = Color(0.02, 0.04, 0.08)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_GOLD = Color(0.9, 0.8, 0.2)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Stars
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	for i in range(60):
		var star = ColorRect.new()
		star.color = COLOR_GOLD
		star.color.a = rng.randf_range(0.2, 0.8)
		star.size = Vector2(3, 3)
		star.position = Vector2(rng.randi_range(0, 1280), rng.randi_range(0, 720))
		add_child(star)

	var title = Label.new()
	title.text = "VICTORY"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var sub = Label.new()
	sub.text = "The Rebel Flagship has been destroyed.\nThe galaxy is safe... for now."
	sub.position = Vector2(0, 280)
	sub.size = Vector2(1280, 100)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 24)
	add_child(sub)

	# Stats
	var stats = Label.new()
	stats.text = "Sectors cleared: " + str(main.sector) + "\nFinal hull: " + str(main.hull) + "/" + str(main.max_hull) + "\nScrap collected: " + str(main.scrap) + "\nCrew survived: " + str(main.crew.size())
	stats.position = Vector2(0, 400)
	stats.size = Vector2(1280, 150)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	stats.add_theme_font_size_override("font_size", 20)
	add_child(stats)

	var btn = Button.new()
	btn.text = "NEW VOYAGE"
	btn.position = Vector2(540, 600)
	btn.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.18, 0.25)
	sb.border_color = COLOR_GOLD
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
