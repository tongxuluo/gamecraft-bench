extends Node2D

var bg: ColorRect
var title_label: Label
var subtitle_label: Label
var begin_btn: Button

func _ready() -> void:
	bg = ColorRect.new()
	bg.color = Color(0.76, 0.60, 0.32)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "GLADIATOR ARENA TYCOON"
	title_label.position = Vector2(300, 180)
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(0.55, 0.1, 0.1))
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Build your arena. Train your fighters. Glory awaits."
	subtitle_label.position = Vector2(370, 280)
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(0.3, 0.15, 0.0))
	add_child(subtitle_label)

	begin_btn = Button.new()
	begin_btn.text = "BEGIN"
	begin_btn.position = Vector2(540, 420)
	begin_btn.custom_minimum_size = Vector2(200, 60)
	begin_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.72, 0.2)
	style.border_color = Color(0.4, 0.2, 0.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	begin_btn.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.95, 0.82, 0.3)
	begin_btn.add_theme_stylebox_override("hover", hover_style)
	begin_btn.add_theme_font_size_override("font_size", 28)
	begin_btn.add_theme_color_override("font_color", Color(0.2, 0.05, 0.0))
	begin_btn.pressed.connect(_on_begin)
	add_child(begin_btn)

func _on_begin() -> void:
	var main_node: Node = get_parent()
	if main_node.has_method("_switch_screen"):
		main_node._switch_screen("game")
