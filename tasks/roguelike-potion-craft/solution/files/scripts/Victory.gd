extends Node2D

var main: Node = null

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.10, 0.05)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "VICTORY!"
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.40, 0.90, 0.45))
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "All 3 floors completed!"
	subtitle.position = Vector2(0, 250)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	subtitle.add_theme_font_size_override("font_size", 28)
	add_child(subtitle)

	var stats = Label.new()
	stats.text = "Gold earned: " + str(main.gold) + "\nRecipes discovered: " + str(main.discovered_recipes.size()) + "\nCustomers served: " + str(main.customers_served)
	stats.position = Vector2(0, 320)
	stats.size = Vector2(1280, 120)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70))
	stats.add_theme_font_size_override("font_size", 22)
	add_child(stats)

	var btn = Button.new()
	btn.text = "PLAY AGAIN"
	btn.position = Vector2(490, 500)
	btn.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.25, 0.15)
	sb.border_color = Color(0.40, 0.80, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.90, 0.90, 0.85))
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(func(): main.reset_run(); main._enter_title())
	add_child(btn)
