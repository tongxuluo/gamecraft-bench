extends Node2D

var main: Node = null

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.04, 0.04)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "SHOP CLOSED"
	title.position = Vector2(0, 180)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.90, 0.25, 0.20))
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Your reputation has fallen to zero.\nThe townsfolk no longer trust your brews."
	subtitle.position = Vector2(0, 280)
	subtitle.size = Vector2(1280, 80)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.60, 0.55))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	var stats = Label.new()
	stats.text = "Floor reached: " + str(main.current_floor) + "\nGold earned: " + str(main.gold) + "\nRecipes discovered: " + str(main.discovered_recipes.size())
	stats.position = Vector2(0, 380)
	stats.size = Vector2(1280, 100)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.70, 0.65, 0.60))
	stats.add_theme_font_size_override("font_size", 20)
	add_child(stats)

	var btn = Button.new()
	btn.text = "TRY AGAIN"
	btn.position = Vector2(490, 520)
	btn.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.10, 0.10)
	sb.border_color = Color(0.80, 0.30, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.90, 0.85, 0.80))
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(func(): main.reset_run(); main._enter_title())
	add_child(btn)
