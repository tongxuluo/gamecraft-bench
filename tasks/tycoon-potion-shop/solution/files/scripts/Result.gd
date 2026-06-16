extends Node2D

var stats: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.1, 0.06, 0.18)
	add_child(bg)

	var title: Label = Label.new()
	title.text = "Shop Closed - Final Report"
	title.position = Vector2(400, 100)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	add_child(title)

	var gold_val: int = stats.get("gold", 0)
	var sold_val: int = stats.get("potions_sold", 0)
	var earned_val: int = stats.get("total_earned", 0)
	var rep_val: int = stats.get("reputation", 50)
	var days_val: int = stats.get("days", 7)

	var lines: PackedStringArray = PackedStringArray([
		"Days Operated: " + str(days_val),
		"Final Gold: " + str(gold_val),
		"Potions Sold: " + str(sold_val),
		"Total Earned: " + str(earned_val) + "g",
		"Reputation: " + str(rep_val)
	])

	var y: int = 200
	for line in lines:
		var lbl: Label = Label.new()
		lbl.text = line
		lbl.position = Vector2(450, y)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		add_child(lbl)
		y += 50

	# Rating
	var rating: String = "Novice Alchemist"
	if sold_val >= 10:
		rating = "Master Alchemist"
	elif sold_val >= 5:
		rating = "Journeyman Alchemist"
	elif sold_val >= 2:
		rating = "Apprentice Alchemist"

	var rating_lbl: Label = Label.new()
	rating_lbl.text = "Rating: " + rating
	rating_lbl.position = Vector2(450, y + 30)
	rating_lbl.add_theme_font_size_override("font_size", 28)
	rating_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5))
	add_child(rating_lbl)
