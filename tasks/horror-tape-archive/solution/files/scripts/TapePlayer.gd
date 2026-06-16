extends Node2D

var main: Node = null

var night_idx: int = 0
var tape_idx: int = 0
var start_sanity: float = 100.0
var seek_to_anomaly: bool = false

# ---- visual constants -------------------------------------------------------

const COLOR_BG := Color(0.04, 0.05, 0.06)
const COLOR_PANEL := Color(0.10, 0.12, 0.14)
const COLOR_DECK := Color(0.16, 0.16, 0.18)
const COLOR_DECK_LIGHT := Color(0.30, 0.32, 0.34)
const COLOR_ACCENT := Color(0.55, 0.85, 0.55)
const COLOR_TEXT := Color(0.85, 0.92, 0.85)
const COLOR_RED := Color(0.95, 0.22, 0.22)
const COLOR_AMBER := Color(0.95, 0.65, 0.20)
const COLOR_PURPLE := Color(0.75, 0.45, 0.85)
const COLOR_DARK := Color(0.18, 0.20, 0.23)

# Monitor (CRT) viewport area where footage plays.
const MONITOR_RECT := Rect2(80, 80, 800, 460)
# Deck panel (controls / labels) on the right.
const DECK_RECT := Rect2(910, 80, 300, 460)
# Timeline strip at the bottom.
const TIMELINE_RECT := Rect2(80, 580, 1130, 40)

# Tape duration is virtual seconds; the timeline maps 1:1.
const TAPE_DURATION := 60.0
const SCRUB_KEY_RATE := 6.0  # seconds of tape per real second held
const ANOMALY_TOLERANCE := 1.6  # seconds; mark must land within this window

# Sanity costs.
const SANITY_PER_ANOMALY_SEEN := 8.0
const SANITY_PER_FALSE_MARK := 5.0
const SANITY_PER_CORRECT_MARK := 4.0

# ---- runtime state ---------------------------------------------------------

var time_pos: float = 0.0
var playing: bool = true
var sanity: float = 100.0
var marks_made: Array = []  # array of {time, ok}
var anomalies: Array = []   # array of dictionaries {kind, t, found, seen}
var tape_done: bool = false
var feedback_timer: float = 0.0

# Rendering nodes.
var monitor_view: Control = null   # parent for footage scene
var footage_root: Node2D = null
var crt_glow: ColorRect = null
var static_overlay: ColorRect = null
var play_pause_label: Label = null
var time_label: Label = null
var timeline_track: ColorRect = null
var timeline_fill: ColorRect = null
var timeline_marker: ColorRect = null
var anomaly_pips: Array = []  # markers along timeline (after found)
var sanity_label: Label = null
var sanity_bar: ColorRect = null
var found_label: Label = null
var feedback_label: Label = null
var rec_dot: ColorRect = null

# Footage actors -- references so we can move/hide them per frame.
var hallway_walker: ColorRect = null   # baseline figure that walks back and forth
var anomaly_actors: Array = []         # Dictionary entries per anomaly with sprites
var ambient_actors: Array = []         # decoration that drifts (lamps blinking, etc.)
var time_acc: float = 0.0

# Set seeds per (night, tape) so anomaly times are deterministic.
func _seed_for_tape() -> int:
    return (night_idx + 1) * 1000 + (tape_idx + 1) * 17 + 7

# ---- lifecycle -------------------------------------------------------------

func _ready() -> void:
    sanity = start_sanity
    seed(_seed_for_tape())
    _generate_anomalies()

    var bg := ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    _build_top_bar()
    _build_monitor()
    _build_deck()
    _build_timeline()
    _build_footage()

    if seek_to_anomaly and anomalies.size() > 0:
        time_pos = anomalies[0].t
        playing = false

    set_process(true)
    set_process_input(true)
    _update_play_pause_visuals()

func _generate_anomalies() -> void:
    anomalies.clear()
    # Three anomalies per tape, spread across thirds of the runtime.
    var kinds = ["FIGURE", "OBJECT_MOVED", "SHADOW"]
    # Shuffle kinds based on seed.
    kinds.shuffle()
    for i in range(3):
        var slot_low := TAPE_DURATION * (i / 3.0) + 4.0
        var slot_high := TAPE_DURATION * ((i + 1) / 3.0) - 4.0
        var t = lerpf(slot_low, slot_high, randf())
        anomalies.append({
            "kind": kinds[i],
            "t": t,
            "duration": 4.5,
            "found": false,
            "seen": false,
        })

# ---- top bar (HUD) ---------------------------------------------------------

func _build_top_bar() -> void:
    var bar := ColorRect.new()
    bar.color = COLOR_PANEL
    bar.size = Vector2(1280, 60)
    add_child(bar)
    var bar_edge := ColorRect.new()
    bar_edge.color = COLOR_ACCENT
    bar_edge.position = Vector2(0, 58)
    bar_edge.size = Vector2(1280, 2)
    add_child(bar_edge)

    var title := Label.new()
    title.text = "NIGHT %d -- TAPE %d" % [night_idx + 1, tape_idx + 1]
    title.position = Vector2(20, 14)
    title.add_theme_color_override("font_color", COLOR_TEXT)
    title.add_theme_font_size_override("font_size", 24)
    add_child(title)

    var loc_names = [["HALLWAY-A", "LAB-12", "STORAGE-B"],
                     ["COURTYARD", "OFFICE-7", "VAULT-3"],
                     ["SUB-LEVEL", "SECTION-9", "ARCHIVES"]]
    var loc := Label.new()
    loc.text = "CAM: %s" % loc_names[night_idx][tape_idx]
    loc.position = Vector2(280, 18)
    loc.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
    loc.add_theme_font_size_override("font_size", 18)
    add_child(loc)

    found_label = Label.new()
    found_label.text = "FOUND  0 / 3"
    found_label.position = Vector2(540, 18)
    found_label.size = Vector2(200, 24)
    found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    found_label.add_theme_color_override("font_color", COLOR_AMBER)
    found_label.add_theme_font_size_override("font_size", 20)
    add_child(found_label)

    sanity_label = Label.new()
    sanity_label.text = "SANITY"
    sanity_label.position = Vector2(800, 8)
    sanity_label.add_theme_color_override("font_color", COLOR_PURPLE)
    sanity_label.add_theme_font_size_override("font_size", 16)
    add_child(sanity_label)
    var sb_bg := ColorRect.new()
    sb_bg.color = Color(0.08, 0.08, 0.10)
    sb_bg.position = Vector2(800, 30)
    sb_bg.size = Vector2(280, 18)
    add_child(sb_bg)
    sanity_bar = ColorRect.new()
    sanity_bar.color = COLOR_PURPLE
    sanity_bar.position = Vector2(800, 30)
    sanity_bar.size = Vector2(280.0 * (sanity / 100.0), 18)
    add_child(sanity_bar)

    # End-of-tape button (skip to results).
    var end_btn := Button.new()
    end_btn.text = "END TAPE"
    end_btn.position = Vector2(1110, 12)
    end_btn.size = Vector2(140, 36)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_DARK
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    end_btn.add_theme_stylebox_override("normal", sb)
    end_btn.add_theme_stylebox_override("hover", sb)
    end_btn.add_theme_stylebox_override("pressed", sb)
    end_btn.add_theme_color_override("font_color", COLOR_TEXT)
    end_btn.add_theme_font_size_override("font_size", 18)
    end_btn.pressed.connect(func(): _finish_tape())
    add_child(end_btn)

# ---- CRT monitor box -------------------------------------------------------

func _build_monitor() -> void:
    # Monitor outer bezel.
    var bezel := ColorRect.new()
    bezel.color = Color(0.12, 0.12, 0.14)
    bezel.position = MONITOR_RECT.position - Vector2(20, 20)
    bezel.size = MONITOR_RECT.size + Vector2(40, 60)
    add_child(bezel)
    var bezel_edge := ColorRect.new()
    bezel_edge.color = COLOR_DECK_LIGHT
    bezel_edge.position = bezel.position
    bezel_edge.size = Vector2(bezel.size.x, 4)
    add_child(bezel_edge)

    # Monitor screen background (the dark glass).
    var screen := ColorRect.new()
    screen.color = Color(0.06, 0.07, 0.08)
    screen.position = MONITOR_RECT.position
    screen.size = MONITOR_RECT.size
    add_child(screen)

    # Footage parent (clipped via Control with clip_contents).
    monitor_view = Control.new()
    monitor_view.position = MONITOR_RECT.position
    monitor_view.size = MONITOR_RECT.size
    monitor_view.clip_contents = true
    monitor_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(monitor_view)

    footage_root = Node2D.new()
    monitor_view.add_child(footage_root)

    # Static / noise overlay -- modulates each frame.
    static_overlay = ColorRect.new()
    static_overlay.color = Color(0.55, 0.85, 0.55, 0.06)
    static_overlay.position = Vector2(0, 0)
    static_overlay.size = MONITOR_RECT.size
    static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    monitor_view.add_child(static_overlay)

    # CRT scanlines inside monitor.
    for y in range(0, int(MONITOR_RECT.size.y), 4):
        var line := ColorRect.new()
        line.color = Color(0, 0, 0, 0.18)
        line.position = Vector2(0, y)
        line.size = Vector2(MONITOR_RECT.size.x, 1)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        monitor_view.add_child(line)

    # Timestamp burned into footage (top-right of screen).
    time_label = Label.new()
    time_label.text = "00:00:00"
    time_label.position = Vector2(MONITOR_RECT.size.x - 130, 12)
    time_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
    time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    time_label.add_theme_constant_override("outline_size", 4)
    time_label.add_theme_font_size_override("font_size", 22)
    monitor_view.add_child(time_label)

    # REC dot top-left.
    rec_dot = ColorRect.new()
    rec_dot.color = COLOR_RED
    rec_dot.position = Vector2(16, 16)
    rec_dot.size = Vector2(12, 12)
    rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    monitor_view.add_child(rec_dot)
    var rec_lab := Label.new()
    rec_lab.text = "REC"
    rec_lab.position = Vector2(34, 12)
    rec_lab.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
    rec_lab.add_theme_font_size_override("font_size", 18)
    monitor_view.add_child(rec_lab)

    # Soft glow strip across top to fake the CRT highlight.
    crt_glow = ColorRect.new()
    crt_glow.color = Color(1, 1, 1, 0.04)
    crt_glow.position = Vector2(0, 0)
    crt_glow.size = Vector2(MONITOR_RECT.size.x, 80)
    crt_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    monitor_view.add_child(crt_glow)

# ---- footage construction --------------------------------------------------

func _build_footage() -> void:
    # Pick a layout per tape so the three tapes per night feel distinct.
    var layout := tape_idx
    if layout == 0:
        _build_hallway()
    elif layout == 1:
        _build_lab()
    else:
        _build_storage()

    _build_anomaly_actors()

func _build_hallway() -> void:
    # Floor and walls -- vanishing-point hallway in flat colors.
    var floor := ColorRect.new()
    floor.color = Color(0.10, 0.11, 0.13)
    floor.position = Vector2(0, MONITOR_RECT.size.y * 0.55)
    floor.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.45)
    floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(floor)

    var ceil := ColorRect.new()
    ceil.color = Color(0.05, 0.05, 0.06)
    ceil.position = Vector2(0, 0)
    ceil.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.30)
    ceil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(ceil)

    var wall_l := ColorRect.new()
    wall_l.color = Color(0.16, 0.16, 0.18)
    wall_l.position = Vector2(0, MONITOR_RECT.size.y * 0.30)
    wall_l.size = Vector2(MONITOR_RECT.size.x * 0.5, MONITOR_RECT.size.y * 0.25)
    wall_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(wall_l)
    var wall_r := ColorRect.new()
    wall_r.color = Color(0.14, 0.14, 0.17)
    wall_r.position = Vector2(MONITOR_RECT.size.x * 0.5, MONITOR_RECT.size.y * 0.30)
    wall_r.size = Vector2(MONITOR_RECT.size.x * 0.5, MONITOR_RECT.size.y * 0.25)
    wall_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(wall_r)

    # Ceiling lights.
    for i in range(4):
        var lamp := ColorRect.new()
        lamp.color = Color(0.85, 0.85, 0.65)
        lamp.position = Vector2(80 + i * 180, 18)
        lamp.size = Vector2(60, 8)
        lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footage_root.add_child(lamp)
        ambient_actors.append({"node": lamp, "kind": "lamp", "phase": i * 0.5})

    # Doors along walls.
    for i in range(3):
        var door := ColorRect.new()
        door.color = Color(0.30, 0.20, 0.14)
        door.position = Vector2(60 + i * 250, MONITOR_RECT.size.y * 0.32)
        door.size = Vector2(60, 100)
        door.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footage_root.add_child(door)

    # Baseline walker -- a normal employee figure pacing.
    hallway_walker = ColorRect.new()
    hallway_walker.color = Color(0.40, 0.42, 0.46)
    hallway_walker.position = Vector2(100, MONITOR_RECT.size.y * 0.50)
    hallway_walker.size = Vector2(28, 70)
    hallway_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(hallway_walker)

func _build_lab() -> void:
    # Lab: counters, beakers, a desk -- mostly horizontal slabs of color.
    var floor := ColorRect.new()
    floor.color = Color(0.18, 0.19, 0.20)
    floor.position = Vector2(0, MONITOR_RECT.size.y * 0.60)
    floor.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.40)
    floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(floor)

    var wall := ColorRect.new()
    wall.color = Color(0.10, 0.12, 0.16)
    wall.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.60)
    wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(wall)

    var counter := ColorRect.new()
    counter.color = Color(0.30, 0.32, 0.36)
    counter.position = Vector2(40, MONITOR_RECT.size.y * 0.55)
    counter.size = Vector2(MONITOR_RECT.size.x - 80, 30)
    counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(counter)

    # Stationary beakers (some are anomaly objects -- those are added later).
    for i in range(5):
        var beaker := ColorRect.new()
        beaker.color = Color(0.55, 0.85, 0.55, 0.85)
        beaker.position = Vector2(80 + i * 130, MONITOR_RECT.size.y * 0.50)
        beaker.size = Vector2(20, 30)
        beaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footage_root.add_child(beaker)
        ambient_actors.append({"node": beaker, "kind": "beaker", "phase": float(i)})

    # A worker bench.
    var monitor_box := ColorRect.new()
    monitor_box.color = Color(0.10, 0.10, 0.12)
    monitor_box.position = Vector2(620, MONITOR_RECT.size.y * 0.40)
    monitor_box.size = Vector2(110, 60)
    monitor_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(monitor_box)
    var monitor_glow := ColorRect.new()
    monitor_glow.color = Color(0.25, 0.65, 0.45, 0.6)
    monitor_glow.position = Vector2(626, MONITOR_RECT.size.y * 0.40 + 6)
    monitor_glow.size = Vector2(98, 48)
    monitor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(monitor_glow)
    ambient_actors.append({"node": monitor_glow, "kind": "screen", "phase": 0.0})

    hallway_walker = ColorRect.new()
    hallway_walker.color = Color(0.50, 0.50, 0.50)
    hallway_walker.position = Vector2(120, MONITOR_RECT.size.y * 0.55)
    hallway_walker.size = Vector2(26, 60)
    hallway_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(hallway_walker)

func _build_storage() -> void:
    # Storage: shelves of boxes; figure stands behind them.
    var floor := ColorRect.new()
    floor.color = Color(0.12, 0.11, 0.10)
    floor.position = Vector2(0, MONITOR_RECT.size.y * 0.65)
    floor.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.35)
    floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(floor)

    var wall := ColorRect.new()
    wall.color = Color(0.08, 0.08, 0.09)
    wall.size = Vector2(MONITOR_RECT.size.x, MONITOR_RECT.size.y * 0.65)
    wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(wall)

    # Shelves with stacks of boxes.
    for shelf_x in [80, 320, 560]:
        var shelf := ColorRect.new()
        shelf.color = Color(0.30, 0.20, 0.14)
        shelf.position = Vector2(shelf_x, MONITOR_RECT.size.y * 0.30)
        shelf.size = Vector2(160, 220)
        shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
        footage_root.add_child(shelf)
        for row in range(3):
            for col in range(2):
                var box := ColorRect.new()
                box.color = Color(0.40, 0.30, 0.20)
                box.position = Vector2(shelf_x + 10 + col * 75, MONITOR_RECT.size.y * 0.30 + 10 + row * 70)
                box.size = Vector2(60, 50)
                box.mouse_filter = Control.MOUSE_FILTER_IGNORE
                footage_root.add_child(box)
                ambient_actors.append({"node": box, "kind": "box", "phase": float(row + col)})

    # Far figure (camera only sees outline).
    hallway_walker = ColorRect.new()
    hallway_walker.color = Color(0.20, 0.22, 0.26)
    hallway_walker.position = Vector2(740, MONITOR_RECT.size.y * 0.55)
    hallway_walker.size = Vector2(24, 60)
    hallway_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footage_root.add_child(hallway_walker)

func _build_anomaly_actors() -> void:
    anomaly_actors.clear()
    for a in anomalies:
        var actor: ColorRect = null
        var label: Label = null
        if a.kind == "FIGURE":
            actor = ColorRect.new()
            actor.color = Color(0.10, 0.10, 0.10)
            actor.position = Vector2(MONITOR_RECT.size.x * 0.62, MONITOR_RECT.size.y * 0.32)
            actor.size = Vector2(34, 84)
            actor.visible = false
            actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
            footage_root.add_child(actor)
        elif a.kind == "OBJECT_MOVED":
            actor = ColorRect.new()
            actor.color = Color(0.85, 0.20, 0.20)
            actor.position = Vector2(MONITOR_RECT.size.x * 0.20, MONITOR_RECT.size.y * 0.50)
            actor.size = Vector2(22, 28)
            actor.visible = false
            actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
            footage_root.add_child(actor)
        else:  # SHADOW
            actor = ColorRect.new()
            actor.color = Color(0, 0, 0, 0.85)
            actor.position = Vector2(MONITOR_RECT.size.x * 0.42, MONITOR_RECT.size.y * 0.55)
            actor.size = Vector2(120, 18)
            actor.visible = false
            actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
            footage_root.add_child(actor)
        anomaly_actors.append({"node": actor, "anomaly": a})

# ---- deck (right-side controls panel) --------------------------------------

func _build_deck() -> void:
    var deck := ColorRect.new()
    deck.color = COLOR_DECK
    deck.position = DECK_RECT.position - Vector2(0, 4)
    deck.size = DECK_RECT.size + Vector2(0, 8)
    add_child(deck)
    var deck_edge := ColorRect.new()
    deck_edge.color = COLOR_DECK_LIGHT
    deck_edge.position = deck.position
    deck_edge.size = Vector2(deck.size.x, 4)
    add_child(deck_edge)

    var deck_header := Label.new()
    deck_header.text = "TAPE DECK"
    deck_header.position = DECK_RECT.position + Vector2(0, 12)
    deck_header.size = Vector2(DECK_RECT.size.x, 30)
    deck_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    deck_header.add_theme_color_override("font_color", COLOR_TEXT)
    deck_header.add_theme_font_size_override("font_size", 22)
    add_child(deck_header)

    play_pause_label = Label.new()
    play_pause_label.text = "[ PLAY ]"
    play_pause_label.position = DECK_RECT.position + Vector2(0, 50)
    play_pause_label.size = Vector2(DECK_RECT.size.x, 30)
    play_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    play_pause_label.add_theme_color_override("font_color", COLOR_ACCENT)
    play_pause_label.add_theme_font_size_override("font_size", 18)
    add_child(play_pause_label)

    # Big MARK ANOMALY button.
    var mark_btn := Button.new()
    mark_btn.text = "MARK\nANOMALY"
    mark_btn.position = DECK_RECT.position + Vector2(30, 100)
    mark_btn.size = Vector2(240, 100)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.30, 0.10, 0.10)
    sb.border_color = COLOR_RED
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(6)
    var sb_h := sb.duplicate()
    sb_h.bg_color = Color(0.45, 0.15, 0.15)
    mark_btn.add_theme_stylebox_override("normal", sb)
    mark_btn.add_theme_stylebox_override("hover", sb_h)
    mark_btn.add_theme_stylebox_override("pressed", sb_h)
    mark_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.85))
    mark_btn.add_theme_font_size_override("font_size", 28)
    mark_btn.pressed.connect(func(): _try_mark())
    add_child(mark_btn)

    # PLAY / PAUSE / SCRUB control trio.
    var play_btn := _make_deck_btn("PLAY  >", DECK_RECT.position + Vector2(15, 220))
    play_btn.pressed.connect(func(): _set_playing(true))
    add_child(play_btn)
    var pause_btn := _make_deck_btn("PAUSE ||", DECK_RECT.position + Vector2(155, 220))
    pause_btn.pressed.connect(func(): _set_playing(false))
    add_child(pause_btn)
    var rew_btn := _make_deck_btn("<< REW", DECK_RECT.position + Vector2(15, 280))
    rew_btn.pressed.connect(func(): _scrub(-5.0))
    add_child(rew_btn)
    var ff_btn := _make_deck_btn("FF >>", DECK_RECT.position + Vector2(155, 280))
    ff_btn.pressed.connect(func(): _scrub(5.0))
    add_child(ff_btn)

    # Feedback line.
    feedback_label = Label.new()
    feedback_label.text = ""
    feedback_label.position = DECK_RECT.position + Vector2(0, 360)
    feedback_label.size = Vector2(DECK_RECT.size.x, 60)
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    feedback_label.add_theme_color_override("font_color", COLOR_AMBER)
    feedback_label.add_theme_font_size_override("font_size", 18)
    add_child(feedback_label)

func _make_deck_btn(text: String, pos: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(130, 45)
    var sb := StyleBoxFlat.new()
    sb.bg_color = COLOR_DARK
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    var sb_h := sb.duplicate()
    sb_h.bg_color = Color(0.22, 0.26, 0.22)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb_h)
    b.add_theme_stylebox_override("pressed", sb_h)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 18)
    return b

# ---- timeline strip --------------------------------------------------------

func _build_timeline() -> void:
    timeline_track = ColorRect.new()
    timeline_track.color = Color(0.08, 0.08, 0.10)
    timeline_track.position = TIMELINE_RECT.position
    timeline_track.size = TIMELINE_RECT.size
    add_child(timeline_track)

    var track_edge := ColorRect.new()
    track_edge.color = COLOR_DECK_LIGHT
    track_edge.position = TIMELINE_RECT.position
    track_edge.size = Vector2(TIMELINE_RECT.size.x, 2)
    add_child(track_edge)

    timeline_fill = ColorRect.new()
    timeline_fill.color = Color(0.20, 0.40, 0.28)
    timeline_fill.position = TIMELINE_RECT.position + Vector2(0, 4)
    timeline_fill.size = Vector2(0, TIMELINE_RECT.size.y - 8)
    timeline_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(timeline_fill)

    # Tick marks every 10 seconds.
    var ticks := int(TAPE_DURATION / 10.0)
    for i in range(ticks + 1):
        var x = TIMELINE_RECT.position.x + (TIMELINE_RECT.size.x * (i * 10.0 / TAPE_DURATION))
        var tick := ColorRect.new()
        tick.color = COLOR_DECK_LIGHT
        tick.position = Vector2(x, TIMELINE_RECT.position.y + 4)
        tick.size = Vector2(2, TIMELINE_RECT.size.y - 8)
        tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(tick)
        var tick_label := Label.new()
        tick_label.text = "%02d:%02d" % [int(i * 10) / 60, int(i * 10) % 60]
        tick_label.position = Vector2(x - 22, TIMELINE_RECT.position.y + TIMELINE_RECT.size.y + 4)
        tick_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 0.65))
        tick_label.add_theme_font_size_override("font_size", 14)
        add_child(tick_label)

    timeline_marker = ColorRect.new()
    timeline_marker.color = COLOR_AMBER
    timeline_marker.size = Vector2(4, TIMELINE_RECT.size.y + 12)
    timeline_marker.position = TIMELINE_RECT.position + Vector2(-2, -6)
    timeline_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(timeline_marker)

    # Scrub instructions under the timeline.
    var help := Label.new()
    help.text = "[LEFT] / [RIGHT] = SCRUB    [SPACE] = PLAY/PAUSE    CLICK TIMELINE TO SEEK"
    help.position = Vector2(0, 670)
    help.size = Vector2(1280, 24)
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 0.65))
    help.add_theme_font_size_override("font_size", 16)
    add_child(help)

# ---- playback / scrubbing --------------------------------------------------

func _process(dt: float) -> void:
    if tape_done:
        return
    time_acc += dt
    var dirty := false
    if playing:
        time_pos += dt
        if time_pos >= TAPE_DURATION:
            time_pos = TAPE_DURATION
            playing = false
            _update_play_pause_visuals()
            _finish_tape()
            return
        dirty = true

    # Continuous scrub via held LEFT/RIGHT.
    if Input.is_key_pressed(KEY_LEFT):
        time_pos = clampf(time_pos - SCRUB_KEY_RATE * dt, 0.0, TAPE_DURATION)
        if playing:
            _set_playing(false)
        dirty = true
    elif Input.is_key_pressed(KEY_RIGHT):
        time_pos = clampf(time_pos + SCRUB_KEY_RATE * dt, 0.0, TAPE_DURATION)
        if playing:
            _set_playing(false)
        dirty = true

    _update_footage(dt)
    _update_timeline()
    _update_anomaly_visibility()
    _update_static_overlay()

    if feedback_timer > 0.0:
        feedback_timer -= dt
        if feedback_timer <= 0.0:
            feedback_label.text = ""

    # REC dot pulse.
    if rec_dot != null:
        var pulse = 0.5 + 0.5 * sin(time_acc * 4.0)
        rec_dot.color = Color(0.95, 0.22, 0.22, 0.6 + 0.4 * pulse)

func _update_static_overlay() -> void:
    if static_overlay == null:
        return
    # Static intensifies as sanity falls and during anomalies.
    var base = 0.04 + 0.10 * (1.0 - clampf(sanity / 100.0, 0.0, 1.0))
    var any_seen := false
    for a in anomalies:
        if _anomaly_active(a):
            any_seen = true
            break
    if any_seen:
        base += 0.12
    var jitter = 0.04 * sin(time_acc * 18.0)
    static_overlay.color = Color(0.55, 0.85, 0.55, clampf(base + jitter, 0.0, 0.4))

func _update_play_pause_visuals() -> void:
    if play_pause_label == null:
        return
    play_pause_label.text = "[ PLAYING ]" if playing else "[ PAUSED ]"
    play_pause_label.add_theme_color_override(
        "font_color",
        COLOR_ACCENT if playing else COLOR_AMBER,
    )

func _set_playing(p: bool) -> void:
    playing = p
    _update_play_pause_visuals()

func _scrub(delta: float) -> void:
    time_pos = clampf(time_pos + delta, 0.0, TAPE_DURATION)

# ---- footage scene update --------------------------------------------------

func _update_footage(_dt: float) -> void:
    # Baseline walker animates along x relative to time_pos.
    if hallway_walker != null and is_instance_valid(hallway_walker):
        var walk_t = fmod(time_pos, 8.0) / 8.0
        var dir = 1.0 if int(time_pos / 8.0) % 2 == 0 else -1.0
        var x_min = 60.0
        var x_max = MONITOR_RECT.size.x - 100.0
        var x = lerpf(x_min, x_max, walk_t) if dir > 0 else lerpf(x_max, x_min, walk_t)
        hallway_walker.position.x = x

    # Ambient actors flicker / drift.
    for amb in ambient_actors:
        var node = amb.node
        if not is_instance_valid(node):
            continue
        if amb.kind == "lamp":
            var f = 0.85 + 0.15 * sin(time_acc * 3.0 + amb.phase)
            node.color = Color(0.85 * f, 0.85 * f, 0.65 * f)
        elif amb.kind == "screen":
            var b = 0.4 + 0.2 * sin(time_acc * 5.0)
            node.color = Color(0.20, 0.65 * b + 0.2, 0.45 * b + 0.2, 0.7)
        elif amb.kind == "beaker":
            var k = 0.6 + 0.2 * sin(time_acc * 1.5 + amb.phase)
            node.color = Color(0.55 * k, 0.85 * k, 0.55 * k, 0.85)
        elif amb.kind == "box":
            pass  # static for now -- one of these gets hidden as anomaly

    # Update timestamp burn-in.
    if time_label != null:
        var mm := int(time_pos) / 60
        var ss := int(time_pos) % 60
        var ff := int((time_pos - int(time_pos)) * 30.0)
        time_label.text = "%02d:%02d:%02d" % [mm, ss, ff]

func _anomaly_active(a: Dictionary) -> bool:
    var dur: float = a.duration
    return time_pos >= a.t and time_pos <= a.t + dur

func _update_anomaly_visibility() -> void:
    for entry in anomaly_actors:
        var a: Dictionary = entry.anomaly
        var node = entry.node
        if not is_instance_valid(node):
            continue
        var active := _anomaly_active(a)
        node.visible = active
        if active and not a.seen:
            a.seen = true
            sanity = maxf(sanity - SANITY_PER_ANOMALY_SEEN, 0.0)
            _refresh_sanity()
        # Optional shake/flicker for the anomaly while active.
        if active:
            if a.kind == "FIGURE":
                node.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(time_acc * 12.0))
            elif a.kind == "OBJECT_MOVED":
                node.position.x = MONITOR_RECT.size.x * 0.20 + 2.0 * sin(time_acc * 8.0)
            elif a.kind == "SHADOW":
                node.color = Color(0, 0, 0, 0.6 + 0.3 * sin(time_acc * 6.0))

func _update_timeline() -> void:
    var frac = clampf(time_pos / TAPE_DURATION, 0.0, 1.0)
    if timeline_fill != null:
        timeline_fill.size = Vector2(TIMELINE_RECT.size.x * frac, TIMELINE_RECT.size.y - 8)
    if timeline_marker != null:
        timeline_marker.position = Vector2(
            TIMELINE_RECT.position.x + TIMELINE_RECT.size.x * frac - 2,
            TIMELINE_RECT.position.y - 6,
        )

# ---- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
    if tape_done:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE:
            _set_playing(not playing)
        elif event.keycode == KEY_ENTER:
            _try_mark()
        elif event.keycode == KEY_ESCAPE:
            _finish_tape()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var p: Vector2 = event.position
        if TIMELINE_RECT.has_point(p):
            var frac = clampf((p.x - TIMELINE_RECT.position.x) / TIMELINE_RECT.size.x, 0.0, 1.0)
            time_pos = TAPE_DURATION * frac
            _set_playing(false)

# ---- mark anomaly ----------------------------------------------------------

func _try_mark() -> void:
    if tape_done:
        return
    var hit_idx := -1
    for i in range(anomalies.size()):
        var a = anomalies[i]
        if a.found:
            continue
        if abs(a.t + a.duration * 0.5 - time_pos) <= ANOMALY_TOLERANCE + a.duration * 0.5:
            # Inside the anomaly window or close enough to count.
            if time_pos >= a.t - ANOMALY_TOLERANCE and time_pos <= a.t + a.duration + ANOMALY_TOLERANCE:
                hit_idx = i
                break
    if hit_idx >= 0:
        var a = anomalies[hit_idx]
        a.found = true
        sanity = maxf(sanity - SANITY_PER_CORRECT_MARK, 0.0)
        _refresh_sanity()
        _flash_feedback("MARKED  %s" % a.kind, COLOR_ACCENT)
        _add_timeline_pip(a.t, COLOR_ACCENT)
        marks_made.append({"time": time_pos, "ok": true})
    else:
        sanity = maxf(sanity - SANITY_PER_FALSE_MARK, 0.0)
        _refresh_sanity()
        _flash_feedback("FALSE MARK -2 SANITY", COLOR_RED)
        _add_timeline_pip(time_pos, COLOR_RED)
        marks_made.append({"time": time_pos, "ok": false})

    _refresh_found()
    if _all_anomalies_found():
        _flash_feedback("TAPE COMPLETE", COLOR_ACCENT)
        await get_tree().create_timer(0.6).timeout
        if not tape_done:
            _finish_tape()
    elif sanity <= 0.0:
        _flash_feedback("SANITY ZERO", COLOR_RED)
        await get_tree().create_timer(0.6).timeout
        if not tape_done:
            _finish_tape()

func _all_anomalies_found() -> bool:
    for a in anomalies:
        if not a.found:
            return false
    return true

func _flash_feedback(text: String, color: Color) -> void:
    if feedback_label == null:
        return
    feedback_label.text = text
    feedback_label.add_theme_color_override("font_color", color)
    feedback_timer = 1.4

func _add_timeline_pip(t: float, color: Color) -> void:
    var x = TIMELINE_RECT.position.x + TIMELINE_RECT.size.x * (t / TAPE_DURATION)
    var pip := ColorRect.new()
    pip.color = color
    pip.position = Vector2(x - 3, TIMELINE_RECT.position.y - 14)
    pip.size = Vector2(6, 14)
    pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(pip)
    anomaly_pips.append(pip)

func _refresh_sanity() -> void:
    if sanity_bar != null:
        sanity_bar.size = Vector2(280.0 * (sanity / 100.0), 18)
    if sanity_label != null:
        sanity_label.text = "SANITY  %d%%" % int(sanity)

func _refresh_found() -> void:
    if found_label != null:
        var n := 0
        for a in anomalies:
            if a.found:
                n += 1
        found_label.text = "FOUND  %d / %d" % [n, anomalies.size()]

# ---- finish ----------------------------------------------------------------

func _finish_tape() -> void:
    if tape_done:
        return
    tape_done = true
    var found := 0
    for a in anomalies:
        if a.found:
            found += 1
    if main != null:
        main._on_tape_finished(found, anomalies.size(), sanity)
