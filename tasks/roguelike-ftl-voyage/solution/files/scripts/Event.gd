extends Node2D

var main: Node = null
var event_data: Dictionary = {}

const COLOR_BG = Color(0.04, 0.05, 0.08)
const COLOR_PANEL = Color(0.1, 0.12, 0.16)
const COLOR_TEXT = Color(0.85, 0.9, 0.95)
const COLOR_ACCENT = Color(0.3, 0.6, 0.9)
const COLOR_CHOICE = Color(0.12, 0.15, 0.2)

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Event panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.size = Vector2(800, 500)
	panel.position = Vector2(240, 110)
	add_child(panel)

	# Border
	var border = ColorRect.new()
	border.color = COLOR_ACCENT
	border.size = Vector2(800, 3)
	border.position = Vector2(240, 110)
	add_child(border)

	# Title
	var title = Label.new()
	title.text = event_data.get("title", "Unknown Event")
	title.position = Vector2(280, 130)
	title.size = Vector2(720, 50)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)

	# Event text
	var text_lbl = Label.new()
	text_lbl.text = event_data.get("text", "Something happens...")
	text_lbl.position = Vector2(280, 200)
	text_lbl.size = Vector2(720, 150)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	text_lbl.add_theme_font_size_override("font_size", 20)
	add_child(text_lbl)

	# Choices
	var choices = event_data.get("choices", ["Continue"])
	var y_pos = 380
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = str(i + 1) + ". " + choices[i]
		btn.position = Vector2(320, y_pos)
		btn.size = Vector2(640, 50)
		var sb = StyleBoxFlat.new()
		sb.bg_color = COLOR_CHOICE
		sb.border_color = Color(0.4, 0.5, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_color_override("font_color", COLOR_TEXT)
		btn.add_theme_font_size_override("font_size", 18)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var choice_idx = i
		btn.pressed.connect(_on_choice.bind(choice_idx))
		add_child(btn)
		y_pos += 60

func _on_choice(idx: int) -> void:
	# Apply event outcome based on choice
	if idx == 0:
		# Usually the risky/rewarding choice
		main.scrap += 15
		if randf() < 0.3:
			main.hull -= 3
	# Choice 1 is usually safe/neutral - no effect
	main._enter_sector_map()
