extends Node2D

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.08, 0.05)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title_lbl: Label = Label.new()
	title_lbl.text = "SEASON COMPLETE"
	title_lbl.position = Vector2(440, 150)
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	add_child(title_lbl)

	var stats_lbl: Label = Label.new()
	stats_lbl.text = "Your arena has grown in fame.\nThe crowd chants your name!"
	stats_lbl.position = Vector2(420, 300)
	stats_lbl.add_theme_font_size_override("font_size", 22)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	add_child(stats_lbl)

	var restart_btn: Button = Button.new()
	restart_btn.text = "PLAY AGAIN"
	restart_btn.position = Vector2(530, 480)
	restart_btn.custom_minimum_size = Vector2(220, 60)
	restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.45, 0.1)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.7, 0.3)
	style.set_corner_radius_all(8)
	restart_btn.add_theme_stylebox_override("normal", style)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	restart_btn.pressed.connect(_on_restart)
	add_child(restart_btn)

func _on_restart() -> void:
	var main_node: Node = get_parent()
	if main_node.has_method("_switch_screen"):
		main_node._switch_screen("title")
