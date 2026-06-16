extends Node2D

var main: Node = null
var has_save: bool = false

const COLOR_SKY_TOP := Color(1.0, 0.85, 0.6)
const COLOR_SKY_BOT := Color(1.0, 0.95, 0.85)
const COLOR_PANEL := Color(0.55, 0.45, 0.35)
const COLOR_TEXT := Color(0.95, 0.95, 0.90)

func _ready() -> void:
	var bg_top := ColorRect.new()
	bg_top.color = COLOR_SKY_TOP
	bg_top.size = Vector2(1280, 360)
	add_child(bg_top)

	var bg_bot := ColorRect.new()
	bg_bot.color = COLOR_SKY_BOT
	bg_bot.position = Vector2(0, 360)
	bg_bot.size = Vector2(1280, 360)
	add_child(bg_bot)

	var barn := ColorRect.new()
	barn.color = Color(0.4, 0.3, 0.25)
	barn.position = Vector2(900, 400)
	barn.size = Vector2(200, 180)
	add_child(barn)

	var roof := ColorRect.new()
	roof.color = Color(0.6, 0.2, 0.15)
	roof.position = Vector2(880, 380)
	roof.size = Vector2(240, 30)
	add_child(roof)

	var title_panel := PanelContainer.new()
	title_panel.position = Vector2(340, 120)
	title_panel.size = Vector2(600, 180)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = Color(0.35, 0.25, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	title_panel.add_theme_stylebox_override("panel", sb)
	add_child(title_panel)

	var title := Label.new()
	title.text = "SUNNY VALLEY FARM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 56)
	title.size = Vector2(600, 180)
	title_panel.add_child(title)

	var new_btn := _make_button("New Farm", Vector2(490, 360))
	new_btn.pressed.connect(func(): main._enter_farm(false))
	add_child(new_btn)

	var cont_btn := _make_button("Continue" if has_save else "Continue (no save)", Vector2(490, 460))
	cont_btn.disabled = not has_save
	cont_btn.pressed.connect(func(): main._enter_farm(false))
	add_child(cont_btn)

func _make_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 70)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.border_color = Color(0.35, 0.25, 0.15)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	var sb_dis := sb.duplicate()
	sb_dis.bg_color = Color(0.3, 0.25, 0.2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb_dis)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4))
	b.add_theme_font_size_override("font_size", 32)
	return b
