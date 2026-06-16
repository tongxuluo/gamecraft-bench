extends Node2D

var main: Node = null

const COLOR_BG = Color(0.02, 0.02, 0.03)
const COLOR_GLOW = Color(0.30, 0.85, 0.40)
const COLOR_TEXT = Color(0.75, 0.90, 0.75)
const COLOR_WARN = Color(0.85, 0.30, 0.30)
const COLOR_PANEL = Color(0.08, 0.10, 0.08)

func _ready() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var won = main.triangulated >= 3 and main.battery > 0

    var title = Label.new()
    title.text = "SIGNAL FOUND" if won else "SIGNAL LOST"
    title.position = Vector2(0, 120)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", COLOR_GLOW if won else COLOR_WARN)
    title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    title.add_theme_constant_override("outline_size", 6)
    title.add_theme_font_size_override("font_size", 56)
    add_child(title)

    var body = Label.new()
    if won:
        body.text = "You triangulated the source.\nThe final signal was clear:\nthe entity IS the signal.\n\nYou turned off the radio.\nSilence. Safety. For now."
    else:
        body.text = "The battery died.\nDarkness filled the station.\nThe signal found you instead.\n\nNo one will hear your broadcast."
    body.position = Vector2(240, 280)
    body.size = Vector2(800, 220)
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body.autowrap_mode = TextServer.AUTOWRAP_WORD
    body.add_theme_color_override("font_color", COLOR_TEXT)
    body.add_theme_font_size_override("font_size", 24)
    add_child(body)

    var stats = Label.new()
    stats.text = "Signals found: %d  |  Triangulations: %d  |  Battery: %d%%" % [
        main.signals_found, main.triangulated, int(main.battery)]
    stats.position = Vector2(0, 520)
    stats.size = Vector2(1280, 30)
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_color_override("font_color", Color(0.50, 0.60, 0.50))
    stats.add_theme_font_size_override("font_size", 18)
    add_child(stats)

    var restart = _make_button("RESTART", Vector2(520, 600))
    restart.pressed.connect(func(): _restart())
    add_child(restart)

func _restart() -> void:
    main.battery = 100.0
    main.signals_found = 0
    main.pins_placed = 0
    main.triangulated = 0
    main._enter_title()

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
