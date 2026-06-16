extends Node2D

var main: Node = null
var corruption: int = 0

const COLOR_BG = Color(0.02, 0.01, 0.02)
const COLOR_GOLD = Color(0.75, 0.60, 0.30)
const COLOR_RED = Color(0.70, 0.15, 0.10)
const COLOR_TEXT = Color(0.90, 0.85, 0.70)
const COLOR_PANEL = Color(0.10, 0.08, 0.06)

func _ready() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var title = Label.new()
    title.text = "FLOOR  13"
    title.position = Vector2(0, 100)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_RED)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 8)
    title.add_theme_font_size_override("font_size", 64)
    add_child(title)

    var body = Label.new()
    if corruption >= 5:
        body.text = "You delivered them all to the wrong floors.\nThe building consumed their fear.\nNow it consumes you.\n\nYou are the new operator.\nForever."
    else:
        body.text = "You tried to do right by them.\nBut the building always wins.\nFloor 13 was always waiting.\n\nAt least you kept your soul."
    body.position = Vector2(240, 260)
    body.size = Vector2(800, 240)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD
    body.add_theme_color_override("font_color", COLOR_TEXT)
    body.add_theme_font_size_override("font_size", 24)
    add_child(body)

    var stats = Label.new()
    stats.text = "Passengers served: %d  |  Corruption: %d/6" % [main.passengers_served, corruption]
    stats.position = Vector2(0, 500)
    stats.size = Vector2(1280, 30)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
    stats.add_theme_font_size_override("font_size", 18)
    add_child(stats)

    var restart = _make_button("RESTART", Vector2(520, 580))
    restart.pressed.connect(func(): _restart())
    add_child(restart)

func _restart() -> void:
    main.corruption = 0
    main.passengers_served = 0
    main.current_floor = 1
    main.visited_floors.clear()
    main._enter_title()

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
