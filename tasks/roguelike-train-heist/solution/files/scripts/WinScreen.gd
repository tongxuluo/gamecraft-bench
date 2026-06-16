extends Control

var main: Node = null

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.15, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "HEIST SUCCESSFUL!"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	title.position = Vector2(370, 100)
	add_child(title)

	var sub = Label.new()
	sub.text = "You reached the engine and took control of the train!"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	sub.position = Vector2(310, 200)
	add_child(sub)

	# Stats
	var stats_text = "Final Stats:\n"
	stats_text += "  HP: " + str(main.hp) + "/" + str(main.max_hp) + "\n"
	stats_text += "  Gold: " + str(main.gold) + "\n"
	stats_text += "  Items: " + (", ".join(main.inventory) if main.inventory.size() > 0 else "none") + "\n"
	stats_text += "  Turns taken: " + str(main.turn)

	var stats = Label.new()
	stats.text = stats_text
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(1, 1, 1))
	stats.position = Vector2(450, 300)
	add_child(stats)

	# Train visual at bottom
	var train = ColorRect.new()
	train.color = Color(0.2, 0.4, 0.2)
	train.position = Vector2(100, 520)
	train.size = Vector2(1080, 60)
	add_child(train)

	# Play again button
	var btn = Button.new()
	btn.text = "  PLAY AGAIN  "
	btn.position = Vector2(540, 620)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(_on_restart)
	add_child(btn)

func _on_restart() -> void:
	main._setup_run()
	main._enter_title()
