extends Node2D

var main: Node = null
var floor_num: int = 1

const COLOR_BG = Color(0.03, 0.03, 0.04)
const COLOR_TEXT = Color(0.90, 0.85, 0.70)
const COLOR_GOLD = Color(0.75, 0.60, 0.30)
const COLOR_PANEL = Color(0.10, 0.08, 0.06)

const FLOOR_THEMES = {
    1: {"name": "LOBBY", "color": Color(0.12, 0.10, 0.08), "desc": "Empty marble. Footsteps echo."},
    2: {"name": "HOTEL HALLWAY", "color": Color(0.14, 0.08, 0.08), "desc": "Doors stretch to infinity."},
    3: {"name": "FROZEN OFFICE", "color": Color(0.10, 0.12, 0.14), "desc": "Everyone stopped mid-sentence."},
    4: {"name": "BALLROOM", "color": Color(0.16, 0.12, 0.10), "desc": "The floor is gone. Only void below."},
    5: {"name": "FLOODED BASEMENT", "color": Color(0.06, 0.08, 0.12), "desc": "Water rises. Something moves beneath."},
    6: {"name": "MIRROR ROOM", "color": Color(0.10, 0.10, 0.12), "desc": "Your reflection blinks first."},
    7: {"name": "NURSERY", "color": Color(0.14, 0.10, 0.10), "desc": "The mobile turns on its own."},
    8: {"name": "LIBRARY", "color": Color(0.12, 0.10, 0.06), "desc": "Books fall open to the same page."},
    9: {"name": "BOILER ROOM", "color": Color(0.10, 0.06, 0.04), "desc": "Heat without fire."},
    10: {"name": "PENTHOUSE", "color": Color(0.08, 0.08, 0.10), "desc": "The city outside is wrong."},
    11: {"name": "MAINTENANCE", "color": Color(0.08, 0.08, 0.06), "desc": "Cables writhe like veins."},
    12: {"name": "ROOFTOP", "color": Color(0.04, 0.04, 0.06), "desc": "The sky has no stars."},
}

var timer: float = 0.0

func _ready() -> void:
    var theme_data = FLOOR_THEMES.get(floor_num, {"name": "UNKNOWN", "color": COLOR_BG, "desc": "..."})

    var bg = ColorRect.new()
    bg.color = theme_data.color
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var floor_label = Label.new()
    floor_label.text = "FLOOR %d — %s" % [floor_num, theme_data.name]
    floor_label.position = Vector2(0, 60)
    floor_label.size = Vector2(1280, 60)
    floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    floor_label.add_theme_color_override("font_color", COLOR_GOLD)
    floor_label.add_theme_font_size_override("font_size", 36)
    add_child(floor_label)

    var desc = Label.new()
    desc.text = theme_data.desc
    desc.position = Vector2(0, 340)
    desc.size = Vector2(1280, 40)
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.add_theme_color_override("font_color", COLOR_TEXT)
    desc.add_theme_font_size_override("font_size", 24)
    add_child(desc)

    var hint = Label.new()
    hint.text = "The doors will close shortly..."
    hint.position = Vector2(0, 640)
    hint.size = Vector2(1280, 30)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35))
    hint.add_theme_font_size_override("font_size", 18)
    add_child(hint)

    timer = 0.0
    set_process(true)

func _process(dt: float) -> void:
    timer += dt
    if timer >= 3.0:
        set_process(false)
        main._enter_elevator()
