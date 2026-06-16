extends Node2D

var main: Node = null

const COLOR_BG = Color(0.03, 0.04, 0.05)
const COLOR_STATIC = Color(0.20, 0.25, 0.20, 0.6)
const COLOR_GLOW = Color(0.30, 0.85, 0.40)
const COLOR_TEXT = Color(0.75, 0.90, 0.75)
const COLOR_PANEL = Color(0.08, 0.10, 0.08)

var flicker_timer: float = 0.0
var title_label: Label = null

func _ready() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Static noise bars.
    for i in range(30):
        var bar = ColorRect.new()
        bar.color = Color(0.15, 0.18, 0.15, 0.3)
        bar.position = Vector2(0, i * 24)
        bar.size = Vector2(1280, 2)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bar)

    title_label = Label.new()
    title_label.text = "SIGNAL  LOST"
    title_label.position = Vector2(0, 240)
    title_label.size = Vector2(1280, 100)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_color_override("font_color", COLOR_GLOW)
    title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title_label.add_theme_constant_override("outline_size", 6)
    title_label.add_theme_font_size_override("font_size", 64)
    add_child(title_label)

    var subtitle = Label.new()
    subtitle.text = "tune in. triangulate. survive."
    subtitle.position = Vector2(0, 340)
    subtitle.size = Vector2(1280, 40)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.50, 0.65, 0.50))
    subtitle.add_theme_font_size_override("font_size", 22)
    add_child(subtitle)

    var begin = _make_button("TUNE IN", Vector2(520, 500))
    begin.pressed.connect(func(): main._enter_station())
    add_child(begin)

    set_process(true)

func _process(dt: float) -> void:
    flicker_timer += dt
    if title_label and is_instance_valid(title_label):
        var a = 0.85 + 0.15 * sin(flicker_timer * 6.0)
        title_label.modulate.a = a

func _make_button(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(240, 56)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_GLOW
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 24)
    return b
