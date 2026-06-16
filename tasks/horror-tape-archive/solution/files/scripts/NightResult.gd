extends Node2D

var main: Node = null
var night_idx: int = 0
var tape_idx: int = 0
var found: int = 0
var total: int = 0
var sanity: float = 100.0

const COLOR_BG := Color(0.05, 0.06, 0.07)
const COLOR_PANEL := Color(0.12, 0.14, 0.16)
const COLOR_ACCENT := Color(0.55, 0.85, 0.55)
const COLOR_WARN := Color(0.85, 0.40, 0.40)
const COLOR_TEXT := Color(0.85, 0.92, 0.85)
const COLOR_DIM := Color(0.55, 0.55, 0.55)

var fader: ColorRect = null
var fade_time: float = 0.0

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    for y in range(0, 720, 4):
        var s := ColorRect.new()
        s.color = Color(0, 0, 0, 0.10)
        s.position = Vector2(0, y)
        s.size = Vector2(1280, 1)
        s.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(s)

    var panel := ColorRect.new()
    panel.color = COLOR_PANEL
    panel.position = Vector2(340, 160)
    panel.size = Vector2(600, 400)
    add_child(panel)
    var bar := ColorRect.new()
    bar.color = COLOR_ACCENT if found > 0 else COLOR_WARN
    bar.position = Vector2(340, 160)
    bar.size = Vector2(600, 4)
    add_child(bar)

    var header := Label.new()
    header.text = "TAPE REVIEW COMPLETE"
    header.position = Vector2(340, 190)
    header.size = Vector2(600, 60)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", COLOR_ACCENT)
    header.add_theme_font_size_override("font_size", 36)
    add_child(header)

    var stats := Label.new()
    stats.text = "Anomalies found: %d / %d\nSanity remaining: %d%%" % [found, total, int(sanity)]
    stats.position = Vector2(380, 280)
    stats.size = Vector2(520, 80)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.autowrap_mode = TextServer.AUTOWRAP_WORD
    stats.add_theme_color_override("font_color", COLOR_TEXT)
    stats.add_theme_font_size_override("font_size", 22)
    add_child(stats)

    var verdict := Label.new()
    if sanity <= 0:
        verdict.text = "Your mind gave out. The tapes have claimed another archivist."
    elif found >= total:
        verdict.text = "All anomalies logged. The case file is complete."
    else:
        verdict.text = "Partial findings. More tapes remain."
    verdict.position = Vector2(380, 380)
    verdict.size = Vector2(520, 60)
    verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    verdict.autowrap_mode = TextServer.AUTOWRAP_WORD
    verdict.add_theme_color_override("font_color", COLOR_DIM)
    verdict.add_theme_font_size_override("font_size", 18)
    add_child(verdict)

    var next_btn := _make_btn("NEXT TAPE", Vector2(420, 480))
    next_btn.pressed.connect(func(): main._next_tape())
    add_child(next_btn)

    var title_btn := _make_btn("TITLE", Vector2(700, 480))
    title_btn.pressed.connect(func(): main._enter_title())
    add_child(title_btn)

    fader = ColorRect.new()
    fader.color = Color(0, 0, 0, 1)
    fader.size = Vector2(1280, 720)
    fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fader)
    fade_time = 0.0
    set_process(true)

func _process(dt: float) -> void:
    if fader == null or not is_instance_valid(fader):
        return
    fade_time += dt
    var k := clampf(fade_time / 0.5, 0.0, 1.0)
    fader.color.a = 1.0 - k

func _make_btn(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(170, 50)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.18, 0.20, 0.23)
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 22)
    return b
