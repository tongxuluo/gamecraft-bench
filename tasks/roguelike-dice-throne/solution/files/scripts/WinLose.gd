extends Control

var main: Node = null
var is_win: bool = true

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	if is_win:
		bg.color = Color(0.05, 0.12, 0.05)
	else:
		bg.color = Color(0.15, 0.05, 0.05)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Result title
	var title = Label.new()
	if is_win:
		title.text = "VICTORY!"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	else:
		title.text = "DEFEAT"
		title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.position = Vector2(340, 150)
	title.size = Vector2(600, 80)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	if is_win:
		sub.text = "The Dragon Lord has been vanquished!"
	else:
		sub.text = "Your journey ends here... (Fight %d/4)" % (main.current_fight + 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	sub.position = Vector2(340, 260)
	sub.size = Vector2(600, 35)
	add_child(sub)

	# Stats
	var stats = Label.new()
	stats.text = "Equipment collected: %d" % main.equipment_collected.size()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	stats.position = Vector2(440, 330)
	stats.size = Vector2(400, 30)
	add_child(stats)

	var hp_stat = Label.new()
	hp_stat.text = "Final HP: %d/%d" % [main.player_hp, main.player_max_hp]
	hp_stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_stat.add_theme_font_size_override("font_size", 18)
	hp_stat.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hp_stat.position = Vector2(440, 365)
	hp_stat.size = Vector2(400, 30)
	add_child(hp_stat)

	# Play again button
	var btn = Button.new()
	btn.text = "PLAY AGAIN"
	btn.position = Vector2(520, 460)
	btn.size = Vector2(240, 55)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_play_again)
	btn.name = "PlayAgainBtn"
	add_child(btn)

func _on_play_again() -> void:
	main.player_hp = 50
	main.player_max_hp = 50
	main.current_fight = 0
	main.equipment_collected.clear()
	main._init_dice()
	main._enter_title()
