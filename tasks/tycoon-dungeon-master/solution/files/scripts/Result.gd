extends Node2D

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var stats: Dictionary = {}
	if has_meta("stats"):
		stats = get_meta("stats")

	var title: Label = Label.new()
	title.text = "DUNGEON COLLAPSED"
	title.position = Vector2(420, 100)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.1))
	add_child(title)

	var waves_val = stats.get("waves_survived", 0)
	var heroes_val = stats.get("heroes_defeated", 0)
	var gold_val = stats.get("gold_remaining", 0)
	var monsters_val = stats.get("monsters", 0)
	var rooms_val = stats.get("rooms_built", 0)

	var info: Label = Label.new()
	info.text = "Waves Survived: " + str(waves_val) + "\n"
	info.text += "Heroes Defeated: " + str(heroes_val) + "\n"
	info.text += "Gold Remaining: " + str(gold_val) + "\n"
	info.text += "Monsters: " + str(monsters_val) + "\n"
	info.text += "Rooms Built: " + str(rooms_val)
	info.position = Vector2(440, 220)
	info.add_theme_font_size_override("font_size", 24)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(info)

	var btn: Button = Button.new()
	btn.text = "PLAY AGAIN"
	btn.position = Vector2(540, 500)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.15, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 22)
	add_child(btn)
