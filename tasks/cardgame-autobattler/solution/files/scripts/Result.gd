extends Node2D

var main: Node = null
var won: bool = false

const COLOR_BG = Color(0.05, 0.06, 0.08)
const COLOR_PANEL = Color(0.14, 0.16, 0.19)
const COLOR_ACCENT = Color(0.55, 0.60, 0.66)
const COLOR_TEXT = Color(0.90, 0.92, 0.94)
const COLOR_GOLD = Color(0.85, 0.70, 0.30)
const COLOR_RED = Color(0.85, 0.30, 0.30)
const COLOR_GREEN = Color(0.40, 0.85, 0.40)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Result panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(290, 120)
	panel.size = Vector2(700, 480)
	add_child(panel)
	var panel_border = ColorRect.new()
	panel_border.color = COLOR_GOLD if won else COLOR_RED
	panel_border.position = Vector2(290, 120)
	panel_border.size = Vector2(700, 6)
	add_child(panel_border)

	# Title
	var title = Label.new()
	title.text = "VICTORY!" if won else "DEFEATED"
	title.position = Vector2(290, 150)
	title.size = Vector2(700, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GREEN if won else COLOR_RED)
	title.add_theme_font_size_override("font_size", 56)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	if won:
		sub.text = "You survived all 8 rounds!\nYour creature army is undefeated!"
	else:
		sub.text = "Your HP reached 0.\nEliminated in round %d of 8." % main.round_num
	sub.position = Vector2(290, 240)
	sub.size = Vector2(700, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 22)
	add_child(sub)

	# Stats
	var stats = Label.new()
	stats.text = "Final HP: %d\nLevel: %d\nGold: %d" % [main.player_hp, main.player_level, main.player_gold]
	stats.position = Vector2(290, 340)
	stats.size = Vector2(700, 100)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", COLOR_ACCENT)
	stats.add_theme_font_size_override("font_size", 20)
	add_child(stats)

	# Placement
	var placement = Label.new()
	if won:
		placement.text = "PLACEMENT: #1"
	else:
		var place = 8 - main.round_num + 1
		placement.text = "PLACEMENT: #%d" % clampi(place, 2, 8)
	placement.position = Vector2(290, 430)
	placement.size = Vector2(700, 50)
	placement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement.add_theme_color_override("font_color", COLOR_GOLD)
	placement.add_theme_font_size_override("font_size", 28)
	add_child(placement)

	# Play Again button
	var btn = Button.new()
	btn.text = "PLAY AGAIN"
	btn.position = Vector2(490, 510)
	btn.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_play_again)
	add_child(btn)

func _on_play_again() -> void:
	main._enter_title()
