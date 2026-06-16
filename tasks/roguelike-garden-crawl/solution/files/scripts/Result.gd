extends Node2D

var main: Node = null
var won: bool = false

const COLOR_DIM = Color(0, 0, 0, 0.7)
const COLOR_PANEL = Color(0.14, 0.18, 0.10)
const COLOR_WIN = Color(0.45, 0.85, 0.35)
const COLOR_LOSE = Color(0.85, 0.3, 0.3)

func _ready() -> void:
	var dim = ColorRect.new()
	dim.color = COLOR_DIM
	dim.size = Vector2(1280, 720)
	add_child(dim)

	var accent = COLOR_WIN if won else COLOR_LOSE
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(340, 180)
	panel.size = Vector2(600, 360)
	add_child(panel)
	var bar = ColorRect.new()
	bar.color = accent
	bar.position = Vector2(340, 180)
	bar.size = Vector2(600, 6)
	add_child(bar)

	var msg = Label.new()
	msg.text = "GARDEN FLOURISHED!" if won else "GARDEN WITHERED..."
	msg.position = Vector2(340, 210)
	msg.size = Vector2(600, 80)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", accent)
	msg.add_theme_font_size_override("font_size", 42)
	add_child(msg)

	var stats = Label.new()
	stats.text = "Floors cleared: %d\nSeeds collected: %d\nSeason reached: %s" % [
		main.floor_num - 1, main.resources, main.get_season()
	]
	stats.position = Vector2(340, 310)
	stats.size = Vector2(600, 120)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8))
	stats.add_theme_font_size_override("font_size", 22)
	add_child(stats)

	var retry = _make_btn("NEW RUN", Vector2(400, 460))
	retry.pressed.connect(func(): _restart())
	add_child(retry)

	var quit_btn = _make_btn("TITLE", Vector2(660, 460))
	quit_btn.pressed.connect(func(): main._enter_title())
	add_child(quit_btn)

func _restart() -> void:
	main.floor_num = 1
	main.player_hp = 10
	main.energy = 5
	main.resources = 0
	main.season_index = 0
	main._init_deck()
	main._enter_floor()

func _make_btn(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 55)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.08)
	sb.border_color = Color(0.45, 0.75, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
	b.add_theme_font_size_override("font_size", 24)
	return b
