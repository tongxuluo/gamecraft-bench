extends Node2D

var main_node: Node2D = null

func _ready() -> void:
	main_node = get_meta("main") as Node2D
	_build_ui()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title: Label = Label.new()
	title.text = "EMPIRE COMPLETE"
	title.position = Vector2(420, 120)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	add_child(title)

	var final_gold: int = 500
	var final_tracks: int = 0
	var final_trains: int = 0
	if main_node.has_meta("final_gold"):
		final_gold = main_node.get_meta("final_gold") as int
	if main_node.has_meta("final_tracks"):
		final_tracks = main_node.get_meta("final_tracks") as int
	if main_node.has_meta("final_trains"):
		final_trains = main_node.get_meta("final_trains") as int

	var stats: Label = Label.new()
	stats.text = "Final Treasury: " + str(final_gold) + " gold\nRoutes Built: " + str(final_tracks) + "\nTrains Owned: " + str(final_trains)
	stats.position = Vector2(450, 250)
	stats.add_theme_font_size_override("font_size", 26)
	stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	add_child(stats)

	var rank: String = "Novice"
	if final_gold > 1000:
		rank = "Railroad Baron"
	elif final_gold > 600:
		rank = "Rail Magnate"
	elif final_gold > 300:
		rank = "Track Foreman"

	var rank_lbl: Label = Label.new()
	rank_lbl.text = "Rank: " + rank
	rank_lbl.position = Vector2(500, 420)
	rank_lbl.add_theme_font_size_override("font_size", 32)
	rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(rank_lbl)

	var line: ColorRect = ColorRect.new()
	line.color = Color(0.6, 0.4, 0.2)
	line.size = Vector2(400, 3)
	line.position = Vector2(440, 400)
	add_child(line)
