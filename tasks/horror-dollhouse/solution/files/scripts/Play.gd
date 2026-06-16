extends Node2D

var main: Node = null

const COLOR_BG = Color(0.04, 0.03, 0.05)
const COLOR_PANEL = Color(0.12, 0.08, 0.10)
const COLOR_ACCENT = Color(0.45, 0.10, 0.15)
const COLOR_INK = Color(0.85, 0.78, 0.72)
const COLOR_DIM = Color(0.40, 0.35, 0.32)
const COLOR_GLOW = Color(1.0, 0.78, 0.30)
const COLOR_SHADOW = Color(0.02, 0.02, 0.03)

const DOLL_RECT = Rect2(40, 110, 580, 540)
const REAL_RECT = Rect2(660, 110, 580, 540)

# Per-room: list of object dicts, plus a goal predicate id.
# Each object has: id, type (candle/cabinet/chair/box/lamp/door/runeboard),
# doll_rect (top-down), real_rect (side-view), state (false default).
var rooms: Dictionary = {}
var sanity_label: Label = null
var status_label: Label = null
var advance_btn: Button = null
var room_buttons: Dictionary = {}
var sanity_timer: float = 0.0

# Object node lookup so we can repaint without a full rebuild.
var doll_nodes: Dictionary = {}
var real_nodes: Dictionary = {}

func _ready() -> void:
    _build_rooms()
    _build_static()
    _build_room(main.current_room)
    set_process(true)

func _process(delta: float) -> void:
    sanity_timer += delta
    if sanity_timer >= 1.0:
        sanity_timer -= 1.0
        main.sanity = max(0.0, main.sanity - 1.5)
        _refresh_sanity()

# ---------------------------------------------------------------- room data

func _build_rooms() -> void:
    rooms = {
        "parlor": {
            "name": "PARLOR",
            "next": "kitchen",
            "goal": "all_candles_lit",
            "narrative": "Three candles, three lives. Light them and the door above will yield.",
            "objects": [
                {"id": "candle_a", "type": "candle",
                 "doll_rect": Rect2(120, 200, 26, 26),
                 "real_rect": Rect2(740, 360, 50, 90)},
                {"id": "candle_b", "type": "candle",
                 "doll_rect": Rect2(290, 200, 26, 26),
                 "real_rect": Rect2(900, 360, 50, 90)},
                {"id": "candle_c", "type": "candle",
                 "doll_rect": Rect2(460, 200, 26, 26),
                 "real_rect": Rect2(1060, 360, 50, 90)},
                {"id": "chair_p", "type": "chair",
                 "doll_rect": Rect2(280, 420, 60, 60),
                 "real_rect": Rect2(820, 470, 120, 110)},
            ],
        },
        "kitchen": {
            "name": "KITCHEN",
            "next": "attic",
            "goal": "all_cabinets_open",
            "narrative": "What was sealed is hungry. Open every cabinet so the way up appears.",
            "objects": [
                {"id": "cab_a", "type": "cabinet",
                 "doll_rect": Rect2(110, 180, 70, 50),
                 "real_rect": Rect2(720, 280, 140, 110)},
                {"id": "cab_b", "type": "cabinet",
                 "doll_rect": Rect2(260, 180, 70, 50),
                 "real_rect": Rect2(880, 280, 140, 110)},
                {"id": "cab_c", "type": "cabinet",
                 "doll_rect": Rect2(410, 180, 70, 50),
                 "real_rect": Rect2(1040, 280, 140, 110)},
                {"id": "lamp_k", "type": "lamp",
                 "doll_rect": Rect2(530, 320, 30, 30),
                 "real_rect": Rect2(1170, 180, 50, 90)},
            ],
        },
        "attic": {
            "name": "ATTIC",
            "next": "",
            "goal": "truth_revealed",
            "narrative": "Move the chair. Open the box. Look at what wears your face.",
            "objects": [
                {"id": "chair_a", "type": "chair",
                 "doll_rect": Rect2(260, 320, 60, 60),
                 "real_rect": Rect2(820, 480, 120, 110)},
                {"id": "box_a", "type": "box",
                 "doll_rect": Rect2(420, 360, 70, 70),
                 "real_rect": Rect2(1020, 470, 160, 130)},
            ],
        },
    }
    for room_id in rooms.keys():
        for obj in rooms[room_id].objects:
            obj["state"] = false

# ------------------------------------------------------------- static chrome

func _build_static() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var header_bar = ColorRect.new()
    header_bar.color = Color(0.10, 0.06, 0.08)
    header_bar.size = Vector2(1280, 90)
    add_child(header_bar)
    var header_stripe = ColorRect.new()
    header_stripe.color = COLOR_ACCENT
    header_stripe.position = Vector2(0, 88)
    header_stripe.size = Vector2(1280, 2)
    add_child(header_stripe)

    var room_buttons_x = 30
    for room_id in ["parlor", "kitchen", "attic"]:
        var b = _make_room_btn(room_id, Vector2(room_buttons_x, 22))
        add_child(b)
        room_buttons[room_id] = b
        room_buttons_x += 150

    sanity_label = Label.new()
    sanity_label.position = Vector2(540, 28)
    sanity_label.size = Vector2(280, 40)
    sanity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sanity_label.add_theme_color_override("font_color", COLOR_INK)
    sanity_label.add_theme_font_size_override("font_size", 22)
    add_child(sanity_label)

    status_label = Label.new()
    status_label.position = Vector2(40, 670)
    status_label.size = Vector2(1200, 40)
    status_label.add_theme_color_override("font_color", COLOR_INK)
    status_label.add_theme_font_size_override("font_size", 18)
    add_child(status_label)

    var doll_frame = ColorRect.new()
    doll_frame.color = Color(0.08, 0.06, 0.07)
    doll_frame.position = DOLL_RECT.position
    doll_frame.size = DOLL_RECT.size
    add_child(doll_frame)
    var doll_label = Label.new()
    doll_label.text = "DOLLHOUSE  (top-down)"
    doll_label.position = Vector2(50, 92)
    doll_label.size = Vector2(560, 20)
    doll_label.add_theme_color_override("font_color", COLOR_DIM)
    doll_label.add_theme_font_size_override("font_size", 14)
    add_child(doll_label)

    var real_frame = ColorRect.new()
    real_frame.color = Color(0.06, 0.05, 0.06)
    real_frame.position = REAL_RECT.position
    real_frame.size = REAL_RECT.size
    add_child(real_frame)
    var real_label = Label.new()
    real_label.text = "FULL-SIZE HOUSE  (same room)"
    real_label.position = Vector2(670, 92)
    real_label.size = Vector2(560, 20)
    real_label.add_theme_color_override("font_color", COLOR_DIM)
    real_label.add_theme_font_size_override("font_size", 14)
    add_child(real_label)

    advance_btn = _make_action_btn("UNLOCK NEXT", Vector2(1080, 28))
    advance_btn.pressed.connect(func(): _on_advance_pressed())
    add_child(advance_btn)

    _refresh_sanity()
    _refresh_room_buttons()

func _make_room_btn(room_id: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.position = pos
    b.size = Vector2(140, 46)
    b.text = room_id.to_upper()
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    var sb_dis = sb.duplicate()
    sb_dis.bg_color = Color(0.06, 0.04, 0.05)
    sb_dis.border_color = Color(0.18, 0.14, 0.14)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_stylebox_override("disabled", sb_dis)
    b.add_theme_color_override("font_color", COLOR_INK)
    b.add_theme_color_override("font_disabled_color", Color(0.30, 0.26, 0.26))
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(func(): _on_room_pressed(room_id))
    return b

func _make_action_btn(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.position = pos
    b.size = Vector2(170, 46)
    b.text = text
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    var sb_dis = sb.duplicate()
    sb_dis.bg_color = Color(0.06, 0.04, 0.05)
    sb_dis.border_color = Color(0.18, 0.14, 0.14)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_stylebox_override("disabled", sb_dis)
    b.add_theme_color_override("font_color", COLOR_INK)
    b.add_theme_color_override("font_disabled_color", Color(0.30, 0.26, 0.26))
    b.add_theme_font_size_override("font_size", 18)
    return b

# --------------------------------------------------------------- room render

func _build_room(room_id: String) -> void:
    # Wipe existing object nodes (everything tagged in dictionaries).
    for n in doll_nodes.values():
        if is_instance_valid(n):
            n.queue_free()
    for n in real_nodes.values():
        if is_instance_valid(n):
            n.queue_free()
    doll_nodes.clear()
    real_nodes.clear()

    var data = rooms[room_id]
    # Floor / wallpaper for this room (different palette per room).
    var doll_floor = ColorRect.new()
    doll_floor.position = DOLL_RECT.position + Vector2(20, 20)
    doll_floor.size = DOLL_RECT.size - Vector2(40, 40)
    doll_floor.color = _floor_color(room_id, true)
    add_child(doll_floor)
    doll_nodes["__floor"] = doll_floor

    var real_floor = ColorRect.new()
    real_floor.position = REAL_RECT.position + Vector2(20, 20)
    real_floor.size = REAL_RECT.size - Vector2(40, 40)
    real_floor.color = _floor_color(room_id, false)
    add_child(real_floor)
    real_nodes["__floor"] = real_floor

    # Real-side wall divider (floor stripe).
    var floor_stripe = ColorRect.new()
    floor_stripe.color = Color(0.05, 0.04, 0.05)
    floor_stripe.position = Vector2(REAL_RECT.position.x + 20, 600)
    floor_stripe.size = Vector2(REAL_RECT.size.x - 40, 30)
    add_child(floor_stripe)
    real_nodes["__stripe"] = floor_stripe

    # Per-object render.
    for obj in data.objects:
        _build_object(obj)

    _refresh_room_buttons()
    _refresh_status()

func _floor_color(room_id: String, is_doll: bool) -> Color:
    var base = Color(0.16, 0.10, 0.10)
    if room_id == "kitchen":
        base = Color(0.10, 0.13, 0.14)
    elif room_id == "attic":
        base = Color(0.12, 0.09, 0.07)
    if not is_doll:
        base = base.darkened(0.20)
    return base

func _build_object(obj: Dictionary) -> void:
    # Doll-side click target (button so we get press handling for free).
    var d = Button.new()
    d.position = obj.doll_rect.position
    d.size = obj.doll_rect.size
    d.flat = true
    d.focus_mode = Control.FOCUS_NONE
    var sb = StyleBoxFlat.new()
    sb.bg_color = _color_for(obj, true)
    sb.border_color = COLOR_INK
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(2)
    d.add_theme_stylebox_override("normal", sb)
    d.add_theme_stylebox_override("hover", sb)
    d.add_theme_stylebox_override("pressed", sb)
    var label_text = _glyph_for(obj)
    d.text = label_text
    d.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
    d.add_theme_font_size_override("font_size", 14)
    var oid = obj.id
    d.pressed.connect(func(): _on_object_clicked(oid))
    add_child(d)
    doll_nodes[obj.id] = d

    # Real-side mirror block; updated visuals only, not interactive.
    var r = ColorRect.new()
    r.position = obj.real_rect.position
    r.size = obj.real_rect.size
    r.color = _color_for(obj, false)
    add_child(r)
    real_nodes[obj.id] = r

    # A glow halo for lit candles / lamps. Initialised hidden.
    if obj.type == "candle" or obj.type == "lamp":
        var halo = ColorRect.new()
        halo.color = Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, 0.35)
        halo.position = obj.real_rect.position - Vector2(20, 20)
        halo.size = obj.real_rect.size + Vector2(40, 40)
        halo.visible = obj.state
        add_child(halo)
        real_nodes[obj.id + "_halo"] = halo

func _color_for(obj: Dictionary, is_doll: bool) -> Color:
    var t = obj.type
    var on = obj.state
    if t == "candle":
        if on:
            return COLOR_GLOW if not is_doll else Color(1.0, 0.85, 0.45)
        return Color(0.50, 0.45, 0.40) if is_doll else Color(0.30, 0.26, 0.22)
    if t == "lamp":
        if on:
            return COLOR_GLOW if not is_doll else Color(1.0, 0.85, 0.45)
        return Color(0.40, 0.40, 0.45) if is_doll else Color(0.25, 0.25, 0.28)
    if t == "cabinet":
        if on:
            return Color(0.50, 0.10, 0.12) if is_doll else Color(0.40, 0.06, 0.06)
        return Color(0.35, 0.25, 0.18) if is_doll else Color(0.28, 0.20, 0.14)
    if t == "chair":
        if on:
            return Color(0.55, 0.40, 0.30) if is_doll else Color(0.40, 0.30, 0.22)
        return Color(0.45, 0.32, 0.24) if is_doll else Color(0.32, 0.24, 0.18)
    if t == "box":
        if on:
            return Color(0.20, 0.05, 0.10) if is_doll else Color(0.55, 0.05, 0.08)
        return Color(0.30, 0.22, 0.16) if is_doll else Color(0.20, 0.16, 0.12)
    return Color(0.5, 0.5, 0.5)

func _glyph_for(obj: Dictionary) -> String:
    var t = obj.type
    var on = obj.state
    if t == "candle":
        return "*" if on else "i"
    if t == "lamp":
        return "*" if on else "o"
    if t == "cabinet":
        return "[ ]" if on else "[X]"
    if t == "chair":
        return ">" if on else "h"
    if t == "box":
        return "_" if on else "#"
    return "?"

# ---------------------------------------------------------------- input

func _on_object_clicked(obj_id: String) -> void:
    var data = rooms[main.current_room]
    for obj in data.objects:
        if obj.id != obj_id:
            continue
        # Toggle, but a candle / lamp only lights once.
        if obj.type == "candle" or obj.type == "lamp":
            obj.state = true
        elif obj.type == "cabinet" or obj.type == "box":
            obj.state = true
        elif obj.type == "chair":
            obj.state = not obj.state
        _repaint_object(obj)
        _refresh_status()
        break

func _repaint_object(obj: Dictionary) -> void:
    if doll_nodes.has(obj.id):
        var d = doll_nodes[obj.id]
        var sb = StyleBoxFlat.new()
        sb.bg_color = _color_for(obj, true)
        sb.border_color = COLOR_INK
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(2)
        d.add_theme_stylebox_override("normal", sb)
        d.add_theme_stylebox_override("hover", sb)
        d.add_theme_stylebox_override("pressed", sb)
        d.text = _glyph_for(obj)
    if real_nodes.has(obj.id):
        real_nodes[obj.id].color = _color_for(obj, false)
    var halo_key = obj.id + "_halo"
    if real_nodes.has(halo_key):
        real_nodes[halo_key].visible = obj.state

func _on_room_pressed(room_id: String) -> void:
    if not main.unlocked_rooms.has(room_id):
        return
    main.current_room = room_id
    _build_room(room_id)

func _on_advance_pressed() -> void:
    var room_id = main.current_room
    if not _goal_satisfied(room_id):
        return
    var data = rooms[room_id]
    if room_id == "attic":
        main.reach_truth()
        return
    var nxt = data.next
    main.unlock_room(nxt)
    main.current_room = nxt
    _build_room(nxt)

# ---------------------------------------------------------------- predicates

func _goal_satisfied(room_id: String) -> bool:
    var data = rooms[room_id]
    var goal = data.goal
    if goal == "all_candles_lit":
        for obj in data.objects:
            if obj.type == "candle" and not obj.state:
                return false
        return true
    if goal == "all_cabinets_open":
        for obj in data.objects:
            if obj.type == "cabinet" and not obj.state:
                return false
        return true
    if goal == "truth_revealed":
        var moved = false
        var opened = false
        for obj in data.objects:
            if obj.type == "chair" and obj.state:
                moved = true
            if obj.type == "box" and obj.state:
                opened = true
        return moved and opened
    return false

# ---------------------------------------------------------------- refresh

func _refresh_sanity() -> void:
    var pct = int(round(main.sanity))
    sanity_label.text = "SANITY  %d%%" % pct
    var c = COLOR_INK
    if pct < 50:
        c = Color(0.85, 0.45, 0.20)
    if pct < 25:
        c = COLOR_ACCENT
    sanity_label.add_theme_color_override("font_color", c)

func _refresh_room_buttons() -> void:
    for room_id in room_buttons.keys():
        var b = room_buttons[room_id]
        var unlocked = main.unlocked_rooms.has(room_id)
        b.disabled = not unlocked
        var prefix = ""
        if room_id == main.current_room:
            prefix = "> "
        elif not unlocked:
            prefix = "[X] "
        b.text = prefix + room_id.to_upper()

func _refresh_status() -> void:
    var data = rooms[main.current_room]
    var ready_to_advance = _goal_satisfied(main.current_room)
    advance_btn.disabled = not ready_to_advance
    if main.current_room == "attic":
        advance_btn.text = "FACE THE TRUTH"
    else:
        advance_btn.text = "UNLOCK NEXT"
    var head = data.name + ":  " + data.narrative
    if ready_to_advance:
        head += "   --  the way is open."
    status_label.text = head
