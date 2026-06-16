extends Node2D

var main: Node = null

const COLOR_BG = Color(0.04, 0.03, 0.02)
const COLOR_TABLE = Color(0.12, 0.08, 0.05)
const COLOR_CANDLE = Color(0.95, 0.75, 0.30)
const COLOR_TEXT = Color(0.78, 0.72, 0.60)
const COLOR_SCRATCH = Color(0.55, 0.48, 0.35)

var candle_rect: ColorRect = null
var candle_glow: ColorRect = null
var flicker_time: float = 0.0

func _ready() -> void:
	# Dark background
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	# Wooden table surface
	var table = ColorRect.new()
	table.color = COLOR_TABLE
	table.position = Vector2(100, 200)
	table.size = Vector2(1080, 420)
	add_child(table)

	# Table edge highlight
	var edge = ColorRect.new()
	edge.color = Color(0.18, 0.12, 0.07)
	edge.position = Vector2(100, 200)
	edge.size = Vector2(1080, 3)
	add_child(edge)

	# Wood grain lines
	for i in range(8):
		var grain = ColorRect.new()
		grain.color = Color(0.10, 0.06, 0.03, 0.4)
		grain.position = Vector2(120, 240 + i * 50)
		grain.size = Vector2(1040, 1)
		add_child(grain)

	# Candle glow (large soft area)
	candle_glow = ColorRect.new()
	candle_glow.color = Color(0.95, 0.70, 0.20, 0.08)
	candle_glow.position = Vector2(540, 180)
	candle_glow.size = Vector2(200, 200)
	add_child(candle_glow)

	# Candle body
	var candle_base = ColorRect.new()
	candle_base.color = Color(0.85, 0.82, 0.70)
	candle_base.position = Vector2(625, 220)
	candle_base.size = Vector2(30, 60)
	add_child(candle_base)

	# Candle flame
	candle_rect = ColorRect.new()
	candle_rect.color = COLOR_CANDLE
	candle_rect.position = Vector2(632, 200)
	candle_rect.size = Vector2(16, 22)
	add_child(candle_rect)

	# Title scratched into table
	var title = Label.new()
	title.text = "INSCRIPTION"
	title.position = Vector2(0, 320)
	title.size = Vector2(1280, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_SCRATCH)
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var subtitle = Label.new()
	subtitle.text = "~ a dark card game ~"
	subtitle.position = Vector2(0, 390)
	subtitle.size = Vector2(1280, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.40, 0.30))
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	# "Begin" card button
	var card_bg = ColorRect.new()
	card_bg.color = Color(0.18, 0.14, 0.10)
	card_bg.position = Vector2(540, 470)
	card_bg.size = Vector2(200, 80)
	add_child(card_bg)

	var card_border = ColorRect.new()
	card_border.color = Color(0.45, 0.38, 0.25)
	card_border.position = Vector2(540, 470)
	card_border.size = Vector2(200, 3)
	add_child(card_border)

	var card_border_bot = ColorRect.new()
	card_border_bot.color = Color(0.45, 0.38, 0.25)
	card_border_bot.position = Vector2(540, 547)
	card_border_bot.size = Vector2(200, 3)
	add_child(card_border_bot)

	var begin_label = Label.new()
	begin_label.text = "BEGIN"
	begin_label.position = Vector2(540, 480)
	begin_label.size = Vector2(200, 60)
	begin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	begin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	begin_label.add_theme_color_override("font_color", COLOR_TEXT)
	begin_label.add_theme_font_size_override("font_size", 32)
	add_child(begin_label)

	var begin_btn = Button.new()
	begin_btn.flat = true
	begin_btn.position = Vector2(540, 470)
	begin_btn.size = Vector2(200, 80)
	begin_btn.pressed.connect(func(): main._enter_map())
	add_child(begin_btn)

	# Shadowy opponent eyes
	var eye_l = ColorRect.new()
	eye_l.color = Color(0.6, 0.9, 0.5, 0.7)
	eye_l.position = Vector2(590, 120)
	eye_l.size = Vector2(12, 6)
	add_child(eye_l)

	var eye_r = ColorRect.new()
	eye_r.color = Color(0.6, 0.9, 0.5, 0.7)
	eye_r.position = Vector2(678, 120)
	eye_r.size = Vector2(12, 6)
	add_child(eye_r)

	set_process(true)

func _process(dt: float) -> void:
	flicker_time += dt
	if candle_rect != null and is_instance_valid(candle_rect):
		var flicker = 0.85 + 0.15 * sin(flicker_time * 8.0) * cos(flicker_time * 3.7)
		candle_rect.modulate = Color(flicker, flicker * 0.9, flicker * 0.6, 1.0)
		candle_rect.size.y = 18 + 4.0 * sin(flicker_time * 5.0)
	if candle_glow != null and is_instance_valid(candle_glow):
		var glow_a = 0.06 + 0.03 * sin(flicker_time * 6.0)
		candle_glow.color = Color(0.95, 0.70, 0.20, glow_a)
