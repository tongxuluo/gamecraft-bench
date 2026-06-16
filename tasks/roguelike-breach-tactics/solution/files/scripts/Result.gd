extends Node2D

var main: Node = null
var won: bool = false

const COLOR_BG = Color(0.05, 0.06, 0.08)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_ACCENT = Color(0.30, 0.65, 0.90)
const COLOR_TEXT = Color(0.90, 0.93, 0.96)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var result_color = Color(0.3, 0.85, 0.4) if won else Color(0.85, 0.3, 0.3)
	var result_text = "MISSION SUCCESS" if won else "MISSION FAILED"

	var title = Label.new()
	title.text = result_text
	title.position = Vector2(0, 180)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", result_color)
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)

	var desc = Label.new()
	if won:
		desc.text = "All buildings survived the assault.\nThe timeline is secure."
	else:
		desc.text = "The city grid has fallen.\nTimeline lost."
	desc.position = Vector2(0, 300)
	desc.size = Vector2(1280, 80)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc.add_theme_font_size_override("font_size", 22)
	add_child(desc)

	var retry_btn = _make_button("RETRY", Vector2(420, 460))
	retry_btn.pressed.connect(func(): main._enter_battle())
	add_child(retry_btn)

	var menu_btn = _make_button("TITLE", Vector2(680, 460))
	menu_btn.pressed.connect(func(): main._enter_title())
	add_child(menu_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(180, 50)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb.duplicate())
	b.add_theme_stylebox_override("pressed", sb.duplicate())
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 22)
	return b
