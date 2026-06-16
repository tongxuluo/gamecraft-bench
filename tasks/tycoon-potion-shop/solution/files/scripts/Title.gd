extends Node2D

signal begin_pressed

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg: ColorRect = ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.15, 0.08, 0.25)
	add_child(bg)

	# Decorative accent bar
	var accent: ColorRect = ColorRect.new()
	accent.position = Vector2(0, 300)
	accent.size = Vector2(1280, 4)
	accent.color = Color(0.85, 0.65, 0.2)
	add_child(accent)

	# Title label
	var title: Label = Label.new()
	title.text = "Potion Shop Tycoon"
	title.position = Vector2(340, 200)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	add_child(title)

	# Subtitle
	var sub: Label = Label.new()
	sub.text = "Brew. Sell. Prosper."
	sub.position = Vector2(500, 270)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.6, 0.9))
	add_child(sub)

	# Begin button
	var btn: Button = Button.new()
	btn.text = "BEGIN"
	btn.position = Vector2(540, 400)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.2, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.65, 0.3, 0.8)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	btn.pressed.connect(_on_begin)
	add_child(btn)

func _on_begin() -> void:
	emit_signal("begin_pressed")
