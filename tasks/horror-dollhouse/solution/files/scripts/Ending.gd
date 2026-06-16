extends Node2D

var main: Node = null

const COLOR_BG = Color(0.02, 0.01, 0.02)
const COLOR_PANEL = Color(0.12, 0.08, 0.10)
const COLOR_ACCENT = Color(0.45, 0.10, 0.15)
const COLOR_INK = Color(0.85, 0.78, 0.72)
const COLOR_BLOOD = Color(0.55, 0.05, 0.08)

func _ready() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var title = Label.new()
    title.text = "THE TRUTH"
    title.position = Vector2(0, 120)
    title.size = Vector2(1280, 100)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_BLOOD)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_font_size_override("font_size", 72)
    add_child(title)

    var body = Label.new()
    body.text = """You opened the box.

Inside: a doll that wears your face.

The dollhouse was never a toy.
It was a cage.

And you were always inside."""
    body.position = Vector2(240, 280)
    body.size = Vector2(800, 300)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    body.add_theme_color_override("font_color", COLOR_INK)
    body.add_theme_font_size_override("font_size", 26)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD
    add_child(body)

    var sanity_final = Label.new()
    var pct = int(round(main.sanity))
    sanity_final.text = "Final Sanity: %d%%" % pct
    sanity_final.position = Vector2(0, 560)
    sanity_final.size = Vector2(1280, 40)
    sanity_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sanity_final.add_theme_color_override("font_color", COLOR_ACCENT)
    sanity_final.add_theme_font_size_override("font_size", 22)
    add_child(sanity_final)

    var restart = _make_button("RESTART", Vector2(540, 630))
    restart.pressed.connect(func(): main._enter_title())
    add_child(restart)

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
