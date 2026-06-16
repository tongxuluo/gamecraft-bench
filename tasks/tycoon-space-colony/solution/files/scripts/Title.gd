extends Node2D

var bg: ColorRect
var title_label: Label
var subtitle_label: Label
var begin_btn: Button

func _ready() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15, 1.0)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "SPACE COLONY TYCOON"
	title_label.position = Vector2(340, 180)
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Build. Sustain. Survive the void."
	subtitle_label.position = Vector2(450, 260)
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	add_child(subtitle_label)

	begin_btn = Button.new()
	begin_btn.text = "BEGIN"
	begin_btn.position = Vector2(540, 400)
	begin_btn.custom_minimum_size = Vector2(200, 60)
	begin_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.4, 0.6)
	style.border_color = Color(0.0, 0.9, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	begin_btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.0, 0.5, 0.7)
	begin_btn.add_theme_stylebox_override("hover", hover_style)
	begin_btn.add_theme_font_size_override("font_size", 24)
	begin_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	begin_btn.pressed.connect(_on_begin)
	add_child(begin_btn)

func _on_begin() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.go_to("Game")
