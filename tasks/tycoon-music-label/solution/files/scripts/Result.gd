extends Node2D

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.05)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var main_node: Node = get_parent()
	var final_gold: int = int(main_node.get("gold"))
	var final_rep: int = int(main_node.get("reputation"))
	var final_albums: Array = main_node.get("albums_released")
	var final_roster: int = int(main_node.get("roster_size"))

	var title: Label = Label.new()
	title.text = "YEAR END REPORT"
	title.position = Vector2(450, 80)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	add_child(title)

	var stats_text: String = ""
	stats_text += "Final Gold: $" + str(final_gold) + "\n"
	stats_text += "Reputation: " + str(final_rep) + "\n"
	stats_text += "Artists Signed: " + str(final_roster) + "\n"
	stats_text += "Albums Released: " + str(final_albums.size()) + "\n"

	var total_rev: int = 0
	for album in final_albums:
		total_rev += album.get("revenue", 0)
	stats_text += "Total Album Revenue: $" + str(total_rev) + "\n"

	var stats_label: Label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(400, 180)
	stats_label.add_theme_font_size_override("font_size", 22)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	add_child(stats_label)

	var grade: String = "F"
	if final_rep >= 50:
		grade = "S"
	elif final_rep >= 35:
		grade = "A"
	elif final_rep >= 25:
		grade = "B"
	elif final_rep >= 15:
		grade = "C"

	var grade_label: Label = Label.new()
	grade_label.text = "Grade: " + grade
	grade_label.position = Vector2(550, 450)
	grade_label.add_theme_font_size_override("font_size", 48)
	grade_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.8))
	add_child(grade_label)

	var btn: Button = Button.new()
	btn.text = "PLAY AGAIN"
	btn.position = Vector2(530, 560)
	btn.custom_minimum_size = Vector2(220, 55)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.0, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(_on_restart)
	add_child(btn)

func _on_restart() -> void:
	var main_node: Node = get_parent()
	main_node.call("change_screen", "Title")
