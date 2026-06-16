extends Node2D

var bg: ColorRect
var title_label: Label
var begin_btn: Button

func _ready() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.18, 0.45, 0.2)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "Zoo Keeper Tycoon"
	title_label.position = Vector2(340, 180)
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	add_child(title_label)

	var subtitle: Label = Label.new()
	subtitle.text = "Build your dream zoo and delight visitors!"
	subtitle.position = Vector2(400, 270)
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	add_child(subtitle)

	begin_btn = Button.new()
	begin_btn.text = "BEGIN"
	begin_btn.position = Vector2(540, 400)
	begin_btn.custom_minimum_size = Vector2(200, 60)
	begin_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.35, 0.1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	begin_btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.7, 0.45, 0.15)
	begin_btn.add_theme_stylebox_override("hover", hover_style)
	begin_btn.add_theme_font_size_override("font_size", 28)
	begin_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	begin_btn.pressed.connect(_on_begin)
	add_child(begin_btn)

func _on_begin() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.go_to("Game")
