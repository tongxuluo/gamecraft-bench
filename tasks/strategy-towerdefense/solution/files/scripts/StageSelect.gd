extends Node2D

var main: Node = null
var cleared: Array = []

const STAGES := [
    {"id": "stage1", "name": "Outer Perimeter", "rec": 1,
     "enemies": "8x Grunt, 2x Runner, 2x Brute  (3 waves)"},
    {"id": "stage2", "name": "Reactor Core",    "rec": 3,
     "enemies": "4x Runner, 4x Grunt, 5x Brute  (3 waves)"}
]

const COLOR_BG := Color(0.08, 0.09, 0.11)
const COLOR_PANEL := Color(0.18, 0.20, 0.23)
const COLOR_ACCENT := Color(0.55, 0.60, 0.66)
const COLOR_LOCKED := Color(0.30, 0.32, 0.34)

var selected_index: int = 0
var brief_label: Label = null

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var header := Label.new()
    header.text = "SELECT STAGE"
    header.position = Vector2(0, 30)
    header.size = Vector2(1280, 60)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
    header.add_theme_font_size_override("font_size", 36)
    add_child(header)

    for i in range(STAGES.size()):
        var unlocked := i == 0 or cleared.has(STAGES[i - 1].id)
        var btn := _make_stage_btn(i, STAGES[i], unlocked)
        add_child(btn)

    var panel := ColorRect.new()
    panel.color = COLOR_PANEL
    panel.position = Vector2(680, 130)
    panel.size = Vector2(560, 460)
    add_child(panel)
    var border := ColorRect.new()
    border.color = COLOR_ACCENT
    border.position = Vector2(680, 130)
    border.size = Vector2(560, 4)
    add_child(border)

    brief_label = Label.new()
    brief_label.position = Vector2(710, 160)
    brief_label.size = Vector2(500, 400)
    brief_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
    brief_label.add_theme_font_size_override("font_size", 22)
    brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    add_child(brief_label)

    var back := _make_action_btn("BACK", Vector2(40, 640))
    back.pressed.connect(func(): main._enter_title())
    add_child(back)

    var deploy_btn := _make_action_btn("DEPLOY ->", Vector2(1080, 640))
    deploy_btn.pressed.connect(func(): _enter_selected())
    add_child(deploy_btn)

    _refresh_brief()

func _enter_selected() -> void:
    var s = STAGES[selected_index]
    if selected_index > 0 and not cleared.has(STAGES[selected_index - 1].id):
        return
    main._enter_battle(s.id)

func _make_stage_btn(idx: int, stage: Dictionary, unlocked: bool) -> Button:
    var b := Button.new()
    var label := str(stage.name)
    if not unlocked:
        label = "[LOCKED] " + label
    elif cleared.has(stage.id):
        label = "[CLEARED] " + label
    b.text = label
    b.position = Vector2(40, 130 + idx * 90)
    b.size = Vector2(600, 70)
    b.disabled = not unlocked
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL if unlocked else COLOR_LOCKED
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_stylebox_override("disabled", sb)
    b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
    b.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.60))
    b.add_theme_font_size_override("font_size", 26)
    b.pressed.connect(func(): _select(idx))
    return b

func _make_action_btn(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(160, 50)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
    b.add_theme_font_size_override("font_size", 22)
    return b

func _select(idx: int) -> void:
    selected_index = idx
    _refresh_brief()

func _refresh_brief() -> void:
    var s = STAGES[selected_index]
    var status := "CLEARED" if cleared.has(s.id) else "UNCLEARED"
    brief_label.text = "%s\n\nRECOMMENDED LEVEL: %d\n\nINTEL:\n%s\n\nSTATUS: %s" % [
        s.name, s.rec, s.enemies, status,
    ]
