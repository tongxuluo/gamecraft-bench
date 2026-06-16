extends Node2D

var main: Node = null
var night: int = 1
var won: bool = false
var saved: int = 0
var lost: int = 0

const COLOR_DIM = Color(0, 0, 0, 0.70)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_ACCENT_WIN = Color(0.55, 0.85, 0.55)
const COLOR_ACCENT_LOSE = Color(0.85, 0.30, 0.30)
const COLOR_TEXT = Color(0.86, 0.84, 0.78)

var fader: ColorRect = null
var fade_time: float = 0.0

func _ready() -> void:
    var dim = ColorRect.new()
    dim.color = COLOR_DIM
    dim.size = Vector2(1280, 720)
    add_child(dim)

    var accent = COLOR_ACCENT_WIN if won else COLOR_ACCENT_LOSE
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
    msg.text = "DAWN  BREAKS" if won else "THE  LIGHT  FAILED"
    msg.position = Vector2(340, 220)
    msg.size = Vector2(600, 80)
    msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg.add_theme_color_override("font_color", accent)
    msg.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    msg.add_theme_constant_override("outline_size", 6)
    msg.add_theme_font_size_override("font_size", 52)
    add_child(msg)

    var sub = Label.new()
    if won and night == 3:
        sub.text = "You kept the lamp burning through three nights.\nThe storm has passed. The watch is over."
    elif won:
        sub.text = "Night %d survived. The next watch begins at dusk." % night
    else:
        sub.text = "Too many ships were lost to the rocks.\nThe keeper's duty has ended."
    sub.position = Vector2(360, 310)
    sub.size = Vector2(560, 80)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD
    sub.add_theme_color_override("font_color", COLOR_TEXT)
    sub.add_theme_font_size_override("font_size", 20)
    add_child(sub)

    var stats = Label.new()
    stats.text = "Ships saved: %d   Ships lost: %d" % [saved, lost]
    stats.position = Vector2(360, 400)
    stats.size = Vector2(560, 30)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_color_override("font_color", Color(0.70, 0.68, 0.60))
    stats.add_theme_font_size_override("font_size", 18)
    add_child(stats)

    if won and night < 3:
        var next_btn = _make_btn("NEXT  NIGHT", Vector2(440, 460))
        next_btn.pressed.connect(func(): _go_next())
        add_child(next_btn)
    var title_btn = _make_btn("TITLE", Vector2(540, 460) if (won and night < 3) else Vector2(490, 460))
    title_btn.pressed.connect(func(): _go_title())
    add_child(title_btn)

    fader = ColorRect.new()
    fader.color = Color(0, 0, 0, 1)
    fader.size = Vector2(1280, 720)
    fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fader)
    fade_time = 0.0
    set_process(true)

func _make_btn(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(200, 60)
    var sb = StyleBoxFlat.new()
    sb.bg_color = Color(0.16, 0.18, 0.22)
    sb.border_color = Color(0.55, 0.60, 0.66)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    var sb_h = sb.duplicate()
    sb_h.bg_color = Color(0.20, 0.22, 0.26)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb_h)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72))
    b.add_theme_font_size_override("font_size", 24)
    return b

func _go_next() -> void:
    main._enter_game(night + 1)

func _go_title() -> void:
    main._enter_title()

func _process(dt: float) -> void:
    if fader == null or not is_instance_valid(fader):
        return
    fade_time += dt
    var k = clampf(fade_time / 0.6, 0.0, 1.0)
    fader.color.a = 1.0 - k
