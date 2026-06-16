extends Control

var main: Node = null
var reason: String = ""

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.15, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title = Label.new()
	title.text = "HEIST FAILED"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.position = Vector2(440, 100)
	add_child(title)

	var reason_lbl = Label.new()
	reason_lbl.text = reason
	reason_lbl.add_theme_font_size_override("font_size", 24)
	reason_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	reason_lbl.position = Vector2(440, 200)
	add_child(reason_lbl)

	# Stats
	var stats_text = "Run Summary:\n"
	stats_text += "  Reached car: " + str(main.current_car + 1) + " of 8\n"
	stats_text += "  Gold collected: " + str(main.gold) + "\n"
	stats_text += "  Turns survived: " + str(main.turn)

	var stats = Label.new()
	stats.text = stats_text
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stats.position = Vector2(450, 300)
	add_child(stats)

	# Retry button
	var btn = Button.new()
	btn.text = "  TRY AGAIN  "
	btn.position = Vector2(540, 500)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(_on_restart)
	add_child(btn)

func _on_restart() -> void:
	main._setup_run()
	main._enter_title()
