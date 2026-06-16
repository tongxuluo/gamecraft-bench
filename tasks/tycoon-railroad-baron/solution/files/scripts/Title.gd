extends Node2D

var main_node: Node2D = null

func _ready() -> void:
	main_node = get_meta("main") as Node2D
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.1)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Title
	var title: Label = Label.new()
	title.text = "RAILROAD BARON"
	title.position = Vector2(340, 150)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	add_child(title)

	# Subtitle
	var sub: Label = Label.new()
	sub.text = "Build your empire of steel and steam"
	sub.position = Vector2(420, 240)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	add_child(sub)

	# Decorative line
	var line: ColorRect = ColorRect.new()
	line.color = Color(0.6, 0.4, 0.2)
	line.size = Vector2(400, 3)
	line.position = Vector2(440, 290)
	add_child(line)

	# BEGIN button
	var btn: Button = Button.new()
	btn.text = "BEGIN"
	btn.position = Vector2(540, 380)
	btn.custom_minimum_size = Vector2(200, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.3, 0.15)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.65, 0.4, 0.2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	btn.pressed.connect(_on_begin)
	add_child(btn)

func _on_begin() -> void:
	main_node.call("_switch_screen", "Game")
