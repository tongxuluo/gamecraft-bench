extends Node2D

var bg: ColorRect
var title_label: Label
var stats_label: Label
var msg_label: Label
var back_btn: Button

func _ready() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	var result_msg: String = main_node.get_meta("result_msg") if main_node.has_meta("result_msg") else "Colony ended."
	var result_cycle: int = main_node.get_meta("result_cycle") if main_node.has_meta("result_cycle") else 0
	var result_pop: int = main_node.get_meta("result_pop") if main_node.has_meta("result_pop") else 0

	bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	title_label = Label.new()
	title_label.text = "COLONY REPORT"
	title_label.position = Vector2(480, 120)
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	add_child(title_label)

	msg_label = Label.new()
	msg_label.text = result_msg
	msg_label.position = Vector2(380, 250)
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	add_child(msg_label)

	stats_label = Label.new()
	stats_label.text = "Cycles survived: %d\nFinal population: %d" % [result_cycle, result_pop]
	stats_label.position = Vector2(480, 340)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	add_child(stats_label)

	back_btn = Button.new()
	back_btn.text = "TITLE SCREEN"
	back_btn.position = Vector2(530, 480)
	back_btn.custom_minimum_size = Vector2(220, 50)
	back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.2, 0.4)
	style.border_color = Color(0.0, 0.7, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	back_btn.add_theme_stylebox_override("normal", style)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _on_back() -> void:
	var main_node: Node2D = get_meta("main") as Node2D
	main_node.go_to("Title")
