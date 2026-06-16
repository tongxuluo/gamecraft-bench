extends Node2D

var main: Node = null

const COLOR_BG := Color(0.08, 0.06, 0.10)
const COLOR_STONE := Color(0.20, 0.18, 0.16)
const COLOR_ACCENT := Color(0.85, 0.55, 0.15)
const COLOR_TEXT := Color(0.92, 0.90, 0.85)
const COLOR_DARK := Color(0.12, 0.10, 0.08)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Stone wall pattern (decorative bars)
	for i in range(0, 1280, 64):
		var stone = ColorRect.new()
		stone.color = COLOR_STONE
		stone.position = Vector2(i, 0)
		stone.size = Vector2(60, 720)
		add_child(stone)
		var gap = ColorRect.new()
		gap.color = COLOR_DARK
		gap.position = Vector2(i + 60, 0)
		gap.size = Vector2(4, 720)
		add_child(gap)

	# Dark overlay for readability
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(1280, 720)
	add_child(overlay)

	# Title
	var title = Label.new()
	title.text = "SOKOBAN\nDUNGEON"
	title.position = Vector2(0, 80)
	title.size = Vector2(1280, 260)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "Push crates. Avoid enemies. Descend deeper."
	sub.position = Vector2(0, 320)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 22)
	add_child(sub)

	# Play button
	var play_btn = _make_button("ENTER THE DUNGEON", Vector2(440, 420))
	play_btn.pressed.connect(func(): main._enter_game(1))
	add_child(play_btn)

	# Info
	var info = Label.new()
	info.text = "Arrow Keys: Move | Z: Undo | 1/2/3: Use Item"
	info.position = Vector2(0, 620)
	info.size = Vector2(1280, 40)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	info.add_theme_font_size_override("font_size", 18)
	add_child(info)

	# Deepest floor
	if main.deepest_floor > 0:
		var record = Label.new()
		record.text = "Deepest Floor: " + str(main.deepest_floor)
		record.position = Vector2(0, 560)
		record.size = Vector2(1280, 40)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.add_theme_color_override("font_color", COLOR_ACCENT)
		record.add_theme_font_size_override("font_size", 24)
		add_child(record)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(400, 70)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.15, 0.05)
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 28)
	return b
