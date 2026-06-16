extends Node2D

var main: Node = null

const COLOR_BG = Color(0.04, 0.03, 0.02)
const COLOR_TEXT = Color(0.78, 0.72, 0.60)
const COLOR_PANEL = Color(0.12, 0.09, 0.06)
const COLOR_BORDER = Color(0.45, 0.38, 0.25)
const COLOR_OPTION = Color(0.18, 0.14, 0.10)

var event_data = [
	{
		"title": "THE HERMIT",
		"description": "A cloaked figure sits by a dying fire.\nHe offers you a trade...",
		"options": [
			{"text": "Trade a card for a stronger one", "result": "You receive a Wolf card."},
			{"text": "Decline and move on", "result": "You continue on your path."},
		]
	},
	{
		"title": "THE BONE LORD",
		"description": "Bones rattle in the darkness.\nA skeletal hand extends toward you,\noffering forbidden knowledge.",
		"options": [
			{"text": "Accept the knowledge (gain sigil)", "result": "Your next creature gains Airborne."},
			{"text": "Refuse (keep your soul intact)", "result": "Wise. You leave unscathed."},
		]
	},
	{
		"title": "CAMPFIRE",
		"description": "Survivors huddle around a campfire.\nThe warmth is inviting.\nThey offer to strengthen a creature.",
		"options": [
			{"text": "Warm a creature (+1 attack)", "result": "Your Stoat grows fiercer."},
			{"text": "Rest and draw extra cards", "result": "You draw 2 Squirrels."},
			{"text": "Leave quickly", "result": "You slip away into the dark."},
		]
	},
]

var chosen_event = 0
var result_shown = false

func _ready() -> void:
	chosen_event = 0

	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.size = Vector2(1280, 720)
	add_child(bg)

	var data = event_data[chosen_event]

	# Event panel
	var panel = ColorRect.new()
	panel.color = COLOR_PANEL
	panel.position = Vector2(240, 80)
	panel.size = Vector2(800, 560)
	add_child(panel)

	# Border top
	var border_t = ColorRect.new()
	border_t.color = COLOR_BORDER
	border_t.position = Vector2(240, 80)
	border_t.size = Vector2(800, 3)
	add_child(border_t)

	# Border bottom
	var border_b = ColorRect.new()
	border_b.color = COLOR_BORDER
	border_b.position = Vector2(240, 637)
	border_b.size = Vector2(800, 3)
	add_child(border_b)

	# Title
	var title = Label.new()
	title.text = data.title
	title.position = Vector2(240, 100)
	title.size = Vector2(800, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	# Atmospheric decoration - eyes
	var eye_l = ColorRect.new()
	eye_l.color = Color(0.5, 0.8, 0.4, 0.6)
	eye_l.position = Vector2(380, 170)
	eye_l.size = Vector2(10, 5)
	add_child(eye_l)

	var eye_r = ColorRect.new()
	eye_r.color = Color(0.5, 0.8, 0.4, 0.6)
	eye_r.position = Vector2(420, 170)
	eye_r.size = Vector2(10, 5)
	add_child(eye_r)

	# Description
	var desc = Label.new()
	desc.text = data.description
	desc.position = Vector2(300, 200)
	desc.size = Vector2(680, 120)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.add_theme_font_size_override("font_size", 22)
	add_child(desc)

	# Options
	var opt_y = 360
	for i in range(data.options.size()):
		var opt = data.options[i]

		var opt_bg = ColorRect.new()
		opt_bg.color = COLOR_OPTION
		opt_bg.position = Vector2(320, opt_y)
		opt_bg.size = Vector2(640, 55)
		add_child(opt_bg)

		var opt_border = ColorRect.new()
		opt_border.color = COLOR_BORDER
		opt_border.position = Vector2(320, opt_y)
		opt_border.size = Vector2(640, 2)
		add_child(opt_border)

		var opt_lbl = Label.new()
		opt_lbl.text = "> " + opt.text
		opt_lbl.position = Vector2(335, opt_y + 15)
		opt_lbl.size = Vector2(610, 30)
		opt_lbl.add_theme_color_override("font_color", COLOR_TEXT)
		opt_lbl.add_theme_font_size_override("font_size", 20)
		add_child(opt_lbl)

		var btn = Button.new()
		btn.flat = true
		btn.position = Vector2(320, opt_y)
		btn.size = Vector2(640, 55)
		var opt_idx = i
		btn.pressed.connect(func(): _on_option_chosen(opt_idx))
		add_child(btn)

		opt_y += 70

func _on_option_chosen(idx: int) -> void:
	if result_shown:
		return
	result_shown = true

	var data = event_data[chosen_event]
	var result_text = data.options[idx].result

	# Show result
	var result_bg = ColorRect.new()
	result_bg.color = Color(0.0, 0.0, 0.0, 0.8)
	result_bg.position = Vector2(300, 520)
	result_bg.size = Vector2(680, 100)
	add_child(result_bg)

	var result_lbl = Label.new()
	result_lbl.text = result_text
	result_lbl.position = Vector2(320, 535)
	result_lbl.size = Vector2(640, 30)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.60))
	result_lbl.add_theme_font_size_override("font_size", 20)
	add_child(result_lbl)

	var continue_btn = Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.position = Vector2(540, 575)
	continue_btn.size = Vector2(200, 40)
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLOR_OPTION
	sb.border_color = COLOR_BORDER
	sb.set_border_width_all(2)
	continue_btn.add_theme_stylebox_override("normal", sb)
	continue_btn.add_theme_stylebox_override("hover", sb)
	continue_btn.add_theme_stylebox_override("pressed", sb)
	continue_btn.add_theme_color_override("font_color", COLOR_TEXT)
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(func(): main._enter_map())
	add_child(continue_btn)
