extends Node2D

var main: Node = null
var stage_id: String = ""
var won: bool = false

const COLOR_DIM := Color(0, 0, 0, 0.65)
const COLOR_PANEL := Color(0.18, 0.20, 0.23)
const COLOR_ACCENT_WIN := Color(0.55, 0.85, 0.55)
const COLOR_ACCENT_LOSE := Color(0.85, 0.30, 0.30)

func _ready() -> void:
    var dim := ColorRect.new()
    dim.color = COLOR_DIM
    dim.size = Vector2(1280, 720)
    add_child(dim)

    var accent := COLOR_ACCENT_WIN if won else COLOR_ACCENT_LOSE
    var panel := ColorRect.new()
    panel.color = COLOR_PANEL
    panel.position = Vector2(340, 200)
    panel.size = Vector2(600, 320)
    add_child(panel)
    var bar := ColorRect.new()
    bar.color = accent
    bar.position = Vector2(340, 200)
    bar.size = Vector2(600, 6)
    add_child(bar)

    var msg := Label.new()
    msg.text = "VICTORY" if won else "DEFEAT"
    msg.position = Vector2(340, 230)
    msg.size = Vector2(600, 80)
    msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg.add_theme_color_override("font_color", accent)
    msg.add_theme_font_size_override("font_size", 60)
    add_child(msg)

    var sub := Label.new()
    sub.text = "Stage cleared. Progress saved." if won else "The line collapsed."
    sub.position = Vector2(340, 320)
    sub.size = Vector2(600, 40)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
    sub.add_theme_font_size_override("font_size", 24)
    add_child(sub)

    var retry := _make_btn("RETRY", Vector2(390, 420))
    retry.pressed.connect(func(): main._enter_battle(stage_id))
    add_child(retry)

    var back := _make_btn("STAGES", Vector2(660, 420))
    back.pressed.connect(func(): main._enter_stage_select())
    add_child(back)

func _make_btn(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(220, 60)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.14, 0.16)
    sb.border_color = Color(0.55, 0.60, 0.66)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
    b.add_theme_font_size_override("font_size", 26)
    return b
