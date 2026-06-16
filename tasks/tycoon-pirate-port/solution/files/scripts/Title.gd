extends Node2D

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.18)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title_label: Label = Label.new()
	title_label.text = "PIRATE PORT TYCOON"
	title_label.position = Vector2(340, 180)
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.2))
	add_child(title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "Build your haven. Command your fleet. Rule the seas."
	sub_label.position = Vector2(380, 260)
	sub_label.add_theme_font_size_override("font_size", 20)
	sub_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	add_child(sub_label)

	var btn: Button = Button.new()
	btn.text = "BEGIN"
	btn.position = Vector2(540, 400)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.7, 0.55, 0.1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.85, 0.65, 0.15)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(_on_begin)
	add_child(btn)

func _on_begin() -> void:
	var main_node: Node = get_parent()
	main_node.call("_switch_screen", "Game")
