extends Node2D

func _ready() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	var final_gold: int = main_node.get_meta("final_gold") if main_node.has_meta("final_gold") else 0
	var final_visitors: int = main_node.get_meta("final_visitors") if main_node.has_meta("final_visitors") else 0
	var final_animals: int = main_node.get_meta("final_animals") if main_node.has_meta("final_animals") else 0
	var final_day: int = main_node.get_meta("final_day") if main_node.has_meta("final_day") else 30

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.3, 0.12)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title: Label = Label.new()
	title.text = "Season Complete!"
	title.position = Vector2(440, 100)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	add_child(title)

	var stats: Label = Label.new()
	stats.text = "Days Managed: %d\nFinal Gold: %d\nDaily Visitors: %d\nAnimals Housed: %d" % [final_day, final_gold, final_visitors, final_animals]
	stats.position = Vector2(440, 220)
	stats.add_theme_font_size_override("font_size", 28)
	stats.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	add_child(stats)

	var rating: String = "Novice Keeper"
	if final_visitors >= 100:
		rating = "Expert Keeper"
	elif final_visitors >= 50:
		rating = "Skilled Keeper"

	var rating_label: Label = Label.new()
	rating_label.text = "Rating: " + rating
	rating_label.position = Vector2(440, 400)
	rating_label.add_theme_font_size_override("font_size", 32)
	rating_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	add_child(rating_label)

	var restart_btn: Button = Button.new()
	restart_btn.text = "PLAY AGAIN"
	restart_btn.position = Vector2(500, 520)
	restart_btn.custom_minimum_size = Vector2(220, 55)
	restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.5, 0.3, 0.1)
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.corner_radius_bottom_left = 6
	st.corner_radius_bottom_right = 6
	restart_btn.add_theme_stylebox_override("normal", st)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)

func _on_restart() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.go_to("Title")
