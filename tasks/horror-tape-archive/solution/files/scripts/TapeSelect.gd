extends Node2D

var main: Node = null

var night_idx: int = 0
var sanity: float = 100.0
var found_total: int = 0

const COLOR_BG := Color(0.05, 0.06, 0.07)
const COLOR_PANEL := Color(0.12, 0.14, 0.16)
const COLOR_ACCENT := Color(0.55, 0.85, 0.55)
const COLOR_TEXT := Color(0.85, 0.92, 0.85)
const COLOR_DARK := Color(0.18, 0.20, 0.23)
const COLOR_TAPE := Color(0.20, 0.18, 0.16)
const COLOR_LABEL := Color(0.85, 0.80, 0.62)

const NIGHT_NAMES := ["NIGHT 1", "NIGHT 2", "NIGHT 3"]
const TAPE_LABELS := [
    ["HALLWAY-A", "LAB-12", "STORAGE-B"],
    ["COURTYARD", "OFFICE-7", "VAULT-3"],
    ["SUB-LEVEL", "SECTION-9", "ARCHIVES"],
]

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Soft scanline tint.
    for y in range(0, 720, 4):
        var s := ColorRect.new()
        s.color = Color(0, 0, 0, 0.10)
        s.position = Vector2(0, y)
        s.size = Vector2(1280, 1)
        s.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(s)

    # Header strip.
    var header_bg := ColorRect.new()
    header_bg.color = COLOR_PANEL
    header_bg.size = Vector2(1280, 80)
    add_child(header_bg)
    var header_edge := ColorRect.new()
    header_edge.color = COLOR_ACCENT
    header_edge.position = Vector2(0, 78)
    header_edge.size = Vector2(1280, 2)
    add_child(header_edge)

    var title := Label.new()
    title.text = "TAPE SHELF -- %s" % NIGHT_NAMES[night_idx]
    title.position = Vector2(40, 24)
    title.add_theme_color_override("font_color", COLOR_TEXT)
    title.add_theme_font_size_override("font_size", 28)
    add_child(title)

    # Sanity gauge top-right.
    var sanity_label := Label.new()
    sanity_label.text = "SANITY"
    sanity_label.position = Vector2(960, 16)
    sanity_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.85))
    sanity_label.add_theme_font_size_override("font_size", 18)
    add_child(sanity_label)
    var bar_bg := ColorRect.new()
    bar_bg.color = Color(0.10, 0.10, 0.12)
    bar_bg.position = Vector2(960, 42)
    bar_bg.size = Vector2(280, 18)
    add_child(bar_bg)
    var bar := ColorRect.new()
    bar.color = Color(0.75, 0.40, 0.75)
    bar.position = Vector2(960, 42)
    bar.size = Vector2(280.0 * clampf(sanity / 100.0, 0.0, 1.0), 18)
    add_child(bar)
    var pct := Label.new()
    pct.text = "%d%%" % int(sanity)
    pct.position = Vector2(1040, 16)
    pct.size = Vector2(80, 24)
    pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pct.add_theme_color_override("font_color", COLOR_TEXT)
    pct.add_theme_font_size_override("font_size", 18)
    add_child(pct)

    # Found count.
    var found := Label.new()
    found.text = "ANOMALIES FOUND  %d" % found_total
    found.position = Vector2(700, 50)
    found.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
    found.add_theme_font_size_override("font_size", 16)
    add_child(found)

    # Shelf background -- a wood-coloured rectangle with rivets.
    var shelf := ColorRect.new()
    shelf.color = Color(0.16, 0.13, 0.10)
    shelf.position = Vector2(80, 140)
    shelf.size = Vector2(1120, 360)
    add_child(shelf)
    var shelf_top := ColorRect.new()
    shelf_top.color = Color(0.28, 0.22, 0.16)
    shelf_top.position = Vector2(80, 140)
    shelf_top.size = Vector2(1120, 8)
    add_child(shelf_top)
    var shelf_bottom := ColorRect.new()
    shelf_bottom.color = Color(0.10, 0.08, 0.06)
    shelf_bottom.position = Vector2(80, 492)
    shelf_bottom.size = Vector2(1120, 8)
    add_child(shelf_bottom)

    # Three tapes.
    for i in range(3):
        _build_tape_card(i)

    # Hint / instructions.
    var hint := Label.new()
    hint.text = "PICK A TAPE TO REVIEW.  CONTROLS:  SPACE = PLAY/PAUSE   LEFT/RIGHT = SCRUB   CLICK MARK ANOMALY"
    hint.position = Vector2(0, 540)
    hint.size = Vector2(1280, 30)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.85, 0.92, 0.85, 0.7))
    hint.add_theme_font_size_override("font_size", 18)
    add_child(hint)

    # Back to title.
    var back := _make_btn("< TITLE", Vector2(40, 640))
    back.pressed.connect(func(): main._enter_title())
    add_child(back)

    # Skip ahead (advance to result without playing) -- safety in demos.
    var skip := _make_btn("NEXT NIGHT", Vector2(1080, 640))
    skip.pressed.connect(func(): _advance_night())
    add_child(skip)

func _build_tape_card(i: int) -> void:
    var x := 130 + i * 350
    var y := 180

    # Tape body.
    var body := ColorRect.new()
    body.color = COLOR_TAPE
    body.position = Vector2(x, y)
    body.size = Vector2(280, 180)
    add_child(body)
    var rim := ColorRect.new()
    rim.color = Color(0.10, 0.08, 0.06)
    rim.position = Vector2(x, y)
    rim.size = Vector2(280, 6)
    add_child(rim)

    # Two reels (circles approximated as rounded rects).
    for k in range(2):
        var reel := ColorRect.new()
        reel.color = Color(0.08, 0.07, 0.06)
        reel.position = Vector2(x + 30 + k * 130, y + 30)
        reel.size = Vector2(80, 80)
        add_child(reel)
        var hub := ColorRect.new()
        hub.color = Color(0.55, 0.50, 0.40)
        hub.position = Vector2(x + 60 + k * 130, y + 60)
        hub.size = Vector2(20, 20)
        add_child(hub)

    # Window strip across the middle.
    var window := ColorRect.new()
    window.color = Color(0.18, 0.16, 0.14)
    window.position = Vector2(x + 30, y + 70)
    window.size = Vector2(220, 30)
    add_child(window)

    # White label on top with the tape name.
    var label_bg := ColorRect.new()
    label_bg.color = COLOR_LABEL
    label_bg.position = Vector2(x + 20, y + 124)
    label_bg.size = Vector2(240, 44)
    add_child(label_bg)

    var name_label := Label.new()
    var tname: String = TAPE_LABELS[night_idx][i]
    name_label.text = "%s  N%dT%d" % [tname, night_idx + 1, i + 1]
    name_label.position = Vector2(x + 20, y + 128)
    name_label.size = Vector2(240, 36)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label.add_theme_color_override("font_color", Color(0.10, 0.08, 0.06))
    name_label.add_theme_font_size_override("font_size", 18)
    add_child(name_label)

    # Pressable transparent button.
    var btn := Button.new()
    btn.flat = true
    btn.position = Vector2(x, y)
    btn.size = Vector2(280, 180)
    btn.pressed.connect(func(): _select_tape(i))
    add_child(btn)

    # "LOAD" indicator below tape.
    var hint := Label.new()
    hint.text = "[ LOAD ]"
    hint.position = Vector2(x, y + 200)
    hint.size = Vector2(280, 24)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
    hint.add_theme_font_size_override("font_size", 18)
    add_child(hint)

func _select_tape(i: int) -> void:
    main.tape_idx = i
    main._enter_tape_player(false)

func _advance_night() -> void:
    main.night_idx = (main.night_idx + 1) % main.NIGHT_COUNT
    main.tape_idx = 0
    main._enter_tape_select()

func _make_btn(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(170, 50)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_DARK
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 22)
    return b
