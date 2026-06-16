extends Node2D

var main: Node = null
var won: bool = false

const COLOR_BG = Color(0.06, 0.06, 0.08)
const COLOR_TEXT = Color(0.95, 0.90, 0.80)
const COLOR_GOLD = Color(0.90, 0.75, 0.20)
const COLOR_WIN = Color(0.30, 0.75, 0.35)
const COLOR_LOSE = Color(0.75, 0.25, 0.20)
const COLOR_PANEL = Color(0.20, 0.16, 0.12)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var result_text = Label.new()
	result_text.text = "SHOP THRIVES!" if won else "BANKRUPT!"
	result_text.position = Vector2(0, 80)
	result_text.size = Vector2(1280, 60)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.add_theme_color_override("font_color", COLOR_WIN if won else COLOR_LOSE)
	result_text.add_theme_font_size_override("font_size", 52)
	add_child(result_text)

	var subtitle = Label.new()
	subtitle.text = "Your dungeon shop has become legendary!" if won else "You ran out of stock and gold..."
	subtitle.position = Vector2(0, 150)
	subtitle.size = Vector2(1280, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_TEXT)
	subtitle.add_theme_font_size_override("font_size", 20)
	add_child(subtitle)

	# Stats panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(340, 220)
	panel.size = Vector2(600, 280)
	add_child(panel)

	var stats_title = Label.new()
	stats_title.text = "FINAL REPORT"
	stats_title.position = Vector2(340, 230)
	stats_title.size = Vector2(600, 30)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_color_override("font_color", COLOR_GOLD)
	stats_title.add_theme_font_size_override("font_size", 24)
	add_child(stats_title)

	_add_stat("Days Survived:", str(main.day - 1) + " / " + str(main.MAX_DAYS), 280)
	_add_stat("Total Gold:", str(main.gold) + "g", 320)
	_add_stat("Total Profit:", str(main.total_profit) + "g", 360)
	_add_stat("Thieves Caught:", str(main.thieves_caught), 400)
	_add_stat("Shop Level:", str(main.shop_level), 440)

	# Play again button
	var again_btn = _make_button("PLAY AGAIN", Vector2(490, 560))
	again_btn.pressed.connect(func():
		main.day = 1
		main.gold = 50
		main.inventory.clear()
		main.shelves.clear()
		main.shop_level = 1
		main.max_shelves = 4
		main.security_level = 0
		main.thieves_caught = 0
		main.total_profit = 0
		main._init_inventory()
		main._enter_title()
	)
	add_child(again_btn)

func _add_stat(label_text: String, value_text: String, y: int) -> void:
	var l = Label.new()
	l.text = label_text
	l.position = Vector2(400, y)
	l.size = Vector2(250, 30)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_font_size_override("font_size", 20)
	add_child(l)

	var v = Label.new()
	v.text = value_text
	v.position = Vector2(660, y)
	v.size = Vector2(200, 30)
	v.add_theme_color_override("font_color", COLOR_GOLD)
	v.add_theme_font_size_override("font_size", 20)
	add_child(v)

func _make_button(text: String, pos: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 60)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = COLOR_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 24)
	return b
