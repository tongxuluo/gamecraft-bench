extends Node2D

var main: Node = null

const COLOR_BG = Color(0.04, 0.03, 0.05)
const COLOR_GOLD = Color(0.75, 0.60, 0.30)
const COLOR_DARK_GOLD = Color(0.45, 0.35, 0.18)
const COLOR_PANEL = Color(0.10, 0.08, 0.06)
const COLOR_TEXT = Color(0.90, 0.85, 0.70)

func _ready() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Art-deco elevator panel background.
    var panel = ColorRect.new()
    panel.color = COLOR_PANEL
    panel.position = Vector2(440, 120)
    panel.size = Vector2(400, 480)
    add_child(panel)
    var border = ColorRect.new()
    border.color = COLOR_DARK_GOLD
    border.position = Vector2(438, 118)
    border.size = Vector2(404, 484)
    border.z_index = -1
    add_child(border)

    # Floor number indicators (1-13).
    for i in range(13):
        var row = i / 4
        var col = i % 4
        var x = 480 + col * 90
        var y = 160 + row * 100
        var indicator = ColorRect.new()
        indicator.color = COLOR_DARK_GOLD if i < 12 else Color(0.50, 0.08, 0.08)
        indicator.position = Vector2(x, y)
        indicator.size = Vector2(60, 60)
        add_child(indicator)
        var num = Label.new()
        num.text = str(i + 1)
        num.position = Vector2(x, y)
        num.size = Vector2(60, 60)
        num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        num.add_theme_color_override("font_color", COLOR_GOLD)
        num.add_theme_font_size_override("font_size", 24)
        add_child(num)

    # Title.
    var title = Label.new()
    title.text = "FLOOR  13"
    title.position = Vector2(0, 30)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_GOLD)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_font_size_override("font_size", 56)
    add_child(title)

    var subtitle = Label.new()
    subtitle.text = "the elevator always remembers"
    subtitle.position = Vector2(0, 620)
    subtitle.size = Vector2(1280, 30)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.60, 0.55, 0.40))
    subtitle.add_theme_font_size_override("font_size", 20)
    add_child(subtitle)

    var begin = _make_button("CLOSE DOORS", Vector2(520, 650))
    begin.pressed.connect(func(): main._enter_elevator())
    add_child(begin)

func _make_button(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(240, 56)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_GOLD
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 24)
    return b
