extends Node2D

var main: Node = null
var floor_num: int = 2

var _timer: float = 0.0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.05)
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var title = Label.new()
	title.text = "DESCENDING..."
	title.position = Vector2(0, 200)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)

	var floor_lbl = Label.new()
	floor_lbl.text = "Floor %d" % floor_num
	floor_lbl.position = Vector2(0, 320)
	floor_lbl.size = Vector2(1280, 60)
	floor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	floor_lbl.add_theme_font_size_override("font_size", 36)
	add_child(floor_lbl)

	var hint = Label.new()
	hint.text = "More enemies await below..."
	hint.position = Vector2(0, 420)
	hint.size = Vector2(1280, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	hint.add_theme_font_size_override("font_size", 22)
	add_child(hint)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 2.0:
		set_process(false)
		main._enter_game(floor_num)
