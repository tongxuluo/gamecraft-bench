extends Node2D

signal begin_pressed

func _ready() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.12)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title_label: Label = Label.new()
	title_label.text = "DUNGEON MASTER TYCOON"
	title_label.position = Vector2(340, 180)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.1))
	add_child(title_label)

	var subtitle: Label = Label.new()
	subtitle.text = "Dig. Recruit. Defend."
	subtitle.position = Vector2(490, 260)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(subtitle)

	var btn: Button = Button.new()
	btn.text = "BEGIN"
	btn.position = Vector2(540, 400)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.1, 0.1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.8, 0.2, 0.1)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.pressed.connect(_on_begin)
	add_child(btn)

func _on_begin() -> void:
	emit_signal("begin_pressed")
