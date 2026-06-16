extends Node2D

var main: Node = null
var has_save: bool = false

const COLOR_BG_TOP := Color(0.10, 0.11, 0.13)
const COLOR_BG_BOT := Color(0.04, 0.05, 0.06)
const COLOR_PANEL := Color(0.18, 0.20, 0.23)
const COLOR_ACCENT := Color(0.55, 0.60, 0.66)

func _ready() -> void:
    var bg_top := ColorRect.new()
    bg_top.color = COLOR_BG_TOP
    bg_top.size = Vector2(1280, 360)
    add_child(bg_top)
    var bg_bot := ColorRect.new()
    bg_bot.color = COLOR_BG_BOT
    bg_bot.position = Vector2(0, 360)
    bg_bot.size = Vector2(1280, 360)
    add_child(bg_bot)
    var stripe := ColorRect.new()
    stripe.color = COLOR_ACCENT
    stripe.position = Vector2(0, 358)
    stripe.size = Vector2(1280, 4)
    add_child(stripe)

    var title := Label.new()
    title.text = "GUNMETAL\nTOWER DEFENSE"
    title.position = Vector2(0, 100)
    title.size = Vector2(1280, 240)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_font_size_override("font_size", 64)
    add_child(title)

    var start_btn := _make_button("BEGIN", Vector2(490, 440))
    start_btn.pressed.connect(func(): main._enter_stage_select())
    add_child(start_btn)

    var load_btn := _make_button("LOAD" if has_save else "LOAD (no save)", Vector2(490, 520))
    load_btn.disabled = not has_save
    load_btn.pressed.connect(func(): main._enter_stage_select())
    add_child(load_btn)

func _make_button(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(300, 60)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    var sb_dis := sb.duplicate()
    sb_dis.bg_color = Color(0.10, 0.12, 0.14)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_stylebox_override("disabled", sb_dis)
    b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
    b.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.50))
    b.add_theme_font_size_override("font_size", 28)
    return b
