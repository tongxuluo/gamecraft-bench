extends Node2D

var result_data: Dictionary = {}

func _ready() -> void:
	var main_node: Node = get_parent()
	if main_node.get("result_data") != null:
		result_data = main_node.get("result_data") as Dictionary

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.12)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title_label: Label = Label.new()
	title_label.text = "GAME OVER"
	title_label.position = Vector2(480, 100)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	add_child(title_label)

	var reason_text: String = ""
	if result_data.has("reason"):
		reason_text = result_data["reason"] as String
	var reason_label: Label = Label.new()
	reason_label.text = reason_text
	reason_label.position = Vector2(400, 200)
	reason_label.add_theme_font_size_override("font_size", 22)
	reason_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	add_child(reason_label)

	var stats_text: String = ""
	if result_data.has("gold"):
		stats_text += "Gold: " + str(result_data["gold"]) + "\n"
	if result_data.has("reputation"):
		stats_text += "Reputation: " + str(result_data["reputation"]) + "\n"
	if result_data.has("notoriety"):
		stats_text += "Notoriety: " + str(result_data["notoriety"]) + "\n"
	if result_data.has("week"):
		stats_text += "Weeks Survived: " + str(result_data["week"]) + "\n"
	if result_data.has("buildings"):
		stats_text += "Buildings: " + str(result_data["buildings"]) + "\n"
	if result_data.has("crews"):
		stats_text += "Crews: " + str(result_data["crews"])

	var stats_label: Label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(480, 280)
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	add_child(stats_label)
