extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.04, 0.08)
const COLOR_GOLD = Color(0.95, 0.80, 0.20)
const COLOR_RED = Color(0.90, 0.25, 0.25)
const COLOR_PANEL = Color(0.15, 0.12, 0.22)
const COLOR_ACCENT = Color(0.70, 0.55, 0.90)

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(340, 150)
	panel.size = Vector2(600, 400)
	add_child(panel)

	var title = Label.new()
	title.text = "EVICTED!"
	title.position = Vector2(340, 170)
	title.size = Vector2(600, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COLOR_RED)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "You couldn't pay the rent."
	subtitle.position = Vector2(340, 250)
	subtitle.size = Vector2(600, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	add_child(subtitle)

	var stats = Label.new()
	stats.text = "Rounds survived: " + str(main.round_num - 1) + "\nFinal gold: " + str(main.gold) + "\nFinal rent: " + str(main.rent) + "\nSymbols in pool: " + str(main.symbol_pool.size())
	stats.position = Vector2(440, 310)
	stats.size = Vector2(400, 120)
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(stats)

	var retry_btn = _make_button("TRY AGAIN", Vector2(490, 460))
	retry_btn.pressed.connect(_restart)
	add_child(retry_btn)

func _restart() -> void:
	main.gold = 10
	main.rent = 15
	main.round_num = 1
	main.spins_this_cycle = 0
	main._init_symbol_pool()
	main.rng.seed = main.rng.randi()
	main._enter_title()

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_font_size_override("font_size", 24)
	return b
