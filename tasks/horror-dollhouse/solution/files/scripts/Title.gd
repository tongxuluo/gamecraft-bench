extends Node2D

var main: Node = null

const COLOR_BG_TOP = Color(0.05, 0.04, 0.07)
const COLOR_BG_BOT = Color(0.01, 0.01, 0.02)
const COLOR_PANEL = Color(0.12, 0.08, 0.10)
const COLOR_ACCENT = Color(0.45, 0.10, 0.15)
const COLOR_INK = Color(0.85, 0.78, 0.72)
const COLOR_BLOOD = Color(0.55, 0.05, 0.08)

func _ready() -> void:
    var bg_top = ColorRect.new()
    bg_top.color = COLOR_BG_TOP
    bg_top.size = Vector2(1280, 360)
    add_child(bg_top)
    var bg_bot = ColorRect.new()
    bg_bot.color = COLOR_BG_BOT
    bg_bot.position = Vector2(0, 360)
    bg_bot.size = Vector2(1280, 360)
    add_child(bg_bot)

    # Split divider, suggesting dollhouse-vs-real.
    var divider = ColorRect.new()
    divider.color = COLOR_ACCENT
    divider.position = Vector2(638, 80)
    divider.size = Vector2(4, 560)
    add_child(divider)

    # Left preview: dollhouse silhouette (top-down boxy).
    var dh_frame = ColorRect.new()
    dh_frame.color = Color(0.18, 0.14, 0.12)
    dh_frame.position = Vector2(140, 160)
    dh_frame.size = Vector2(420, 360)
    add_child(dh_frame)
    var rooms_left = [
        Vector2(160, 180), Vector2(360, 180),
        Vector2(160, 360), Vector2(360, 360),
    ]
    for p in rooms_left:
        var r = ColorRect.new()
        r.color = Color(0.30, 0.22, 0.18)
        r.position = p
        r.size = Vector2(180, 160)
        add_child(r)

    # Right preview: real house side-view.
    var rh_frame = ColorRect.new()
    rh_frame.color = Color(0.10, 0.10, 0.12)
    rh_frame.position = Vector2(720, 160)
    rh_frame.size = Vector2(420, 360)
    add_child(rh_frame)
    var roof = ColorRect.new()
    roof.color = Color(0.20, 0.06, 0.06)
    roof.position = Vector2(720, 130)
    roof.size = Vector2(420, 30)
    add_child(roof)
    var window_glow = ColorRect.new()
    window_glow.color = Color(0.65, 0.45, 0.20)
    window_glow.position = Vector2(820, 240)
    window_glow.size = Vector2(60, 60)
    add_child(window_glow)
    var window2 = ColorRect.new()
    window2.color = Color(0.18, 0.18, 0.22)
    window2.position = Vector2(980, 240)
    window2.size = Vector2(60, 60)
    add_child(window2)
    var door = ColorRect.new()
    door.color = Color(0.18, 0.10, 0.08)
    door.position = Vector2(900, 400)
    door.size = Vector2(80, 120)
    add_child(door)

    # Title.
    var title = Label.new()
    title.text = "HORROR DOLLHOUSE"
    title.position = Vector2(0, 30)
    title.size = Vector2(1280, 90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_BLOOD)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_font_size_override("font_size", 64)
    add_child(title)

    var subtitle = Label.new()
    subtitle.text = "what moves in the small house, moves in the big one"
    subtitle.position = Vector2(0, 540)
    subtitle.size = Vector2(1280, 40)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", COLOR_INK)
    subtitle.add_theme_font_size_override("font_size", 22)
    add_child(subtitle)

    var begin = _make_button("BEGIN", Vector2(540, 620))
    begin.pressed.connect(func(): main._enter_play())
    add_child(begin)

func _make_button(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(200, 60)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_INK)
    b.add_theme_font_size_override("font_size", 28)
    return b
