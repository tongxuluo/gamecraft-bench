extends Node2D

var main: Node = null

const COLOR_BG := Color(0.04, 0.05, 0.06)
const COLOR_PANEL := Color(0.10, 0.12, 0.14)
const COLOR_ACCENT := Color(0.55, 0.85, 0.55)
const COLOR_TEXT := Color(0.78, 0.95, 0.78)
const COLOR_DARK := Color(0.18, 0.20, 0.23)

var tracking_bands: Array = []
var time_acc: float = 0.0

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Vignette feel: darken edges with two strips.
    for r in [Rect2(0, 0, 1280, 80), Rect2(0, 640, 1280, 80)]:
        var v := ColorRect.new()
        v.color = Color(0, 0, 0, 0.55)
        v.position = r.position
        v.size = r.size
        add_child(v)

    # Scanlines: alternating dim horizontal lines.
    for y in range(0, 720, 4):
        var s := ColorRect.new()
        s.color = Color(0, 0, 0, 0.18)
        s.position = Vector2(0, y)
        s.size = Vector2(1280, 1)
        s.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(s)

    # Tracking bands -- pale wobbling streaks that move down the screen.
    for i in range(4):
        var band := ColorRect.new()
        band.color = Color(0.55, 0.85, 0.55, 0.10)
        band.size = Vector2(1280, 26)
        band.position = Vector2(0, 80 + i * 180)
        band.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(band)
        tracking_bands.append(band)

    # Title card.
    var title := Label.new()
    title.text = "HORROR TAPE\nARCHIVE"
    title.position = Vector2(0, 140)
    title.size = Vector2(1280, 220)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_TEXT)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 8)
    title.add_theme_font_size_override("font_size", 78)
    add_child(title)

    var sub := Label.new()
    sub.text = "FACILITY 7 -- INTERNAL USE ONLY"
    sub.position = Vector2(0, 380)
    sub.size = Vector2(1280, 30)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 0.8))
    sub.add_theme_font_size_override("font_size", 22)
    add_child(sub)

    # REC indicator (top-left).
    var rec_dot := ColorRect.new()
    rec_dot.color = Color(0.95, 0.20, 0.20)
    rec_dot.position = Vector2(40, 40)
    rec_dot.size = Vector2(16, 16)
    add_child(rec_dot)
    var rec_label := Label.new()
    rec_label.text = "REC"
    rec_label.position = Vector2(64, 36)
    rec_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
    rec_label.add_theme_font_size_override("font_size", 22)
    add_child(rec_label)

    # Timestamp (top-right) -- arbitrary but matches the VHS look.
    var ts := Label.new()
    ts.text = "1995-08-13  03:14:00"
    ts.position = Vector2(1000, 36)
    ts.size = Vector2(240, 30)
    ts.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
    ts.add_theme_font_size_override("font_size", 22)
    add_child(ts)

    # PLAY button (tape-deck control look).
    var play_btn := _make_deck_button("PLAY  >", Vector2(490, 460))
    play_btn.pressed.connect(func(): main._enter_tape_select())
    add_child(play_btn)

    # Hint text.
    var hint := Label.new()
    hint.text = "PRESS PLAY TO BEGIN REVIEW"
    hint.position = Vector2(0, 560)
    hint.size = Vector2(1280, 30)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 0.6))
    hint.add_theme_font_size_override("font_size", 20)
    add_child(hint)

    set_process(true)
    set_process_input(true)

func _process(dt: float) -> void:
    time_acc += dt
    for i in range(tracking_bands.size()):
        var band: ColorRect = tracking_bands[i]
        if not is_instance_valid(band):
            continue
        var phase = time_acc * (40.0 + i * 6.0) + i * 90.0
        band.position.y = fmod(phase, 720.0)
        var alpha = 0.06 + 0.06 * sin(time_acc * 3.0 + i)
        band.color = Color(0.55, 0.85, 0.55, alpha)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            main._enter_tape_select()

func _make_deck_button(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(300, 70)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    var sb_h := sb.duplicate()
    sb_h.bg_color = Color(0.16, 0.20, 0.16)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb_h)
    b.add_theme_stylebox_override("pressed", sb_h)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 32)
    return b
