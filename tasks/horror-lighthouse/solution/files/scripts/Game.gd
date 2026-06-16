extends Node2D

var main: Node = null
var night: int = 1
var overrides: Dictionary = {}

# ---- layout / constants ------------------------------------------------

const COLOR_BG = Color(0.04, 0.05, 0.07)
const COLOR_NIGHT_SKY = Color(0.05, 0.07, 0.10)
const COLOR_SEA_TOP = Color(0.06, 0.08, 0.11)
const COLOR_SEA_BOT = Color(0.02, 0.03, 0.05)
const COLOR_INTERIOR_WALL = Color(0.16, 0.13, 0.10)
const COLOR_INTERIOR_DARK = Color(0.10, 0.08, 0.07)
const COLOR_FLOOR_LINE = Color(0.32, 0.26, 0.20)
const COLOR_LAMP_ROOM = Color(0.20, 0.16, 0.12)
const COLOR_QUARTERS = Color(0.18, 0.14, 0.11)
const COLOR_FUEL_ROOM = Color(0.13, 0.11, 0.10)
const COLOR_PANEL = Color(0.10, 0.12, 0.16)
const COLOR_PANEL_LIGHT = Color(0.16, 0.18, 0.22)
const COLOR_ACCENT = Color(0.55, 0.60, 0.66)
const COLOR_ACCENT_WARN = Color(0.85, 0.30, 0.30)
const COLOR_ACCENT_OK = Color(0.45, 0.80, 0.55)
const COLOR_LAMP = Color(1.00, 0.86, 0.55)
const COLOR_LAMP_DIM = Color(0.55, 0.45, 0.25)
const COLOR_TEXT = Color(0.86, 0.84, 0.78)
const COLOR_TEXT_DIM = Color(0.60, 0.58, 0.52)
const COLOR_RAIN = Color(0.65, 0.70, 0.78, 0.55)
const COLOR_CREATURE = Color(0.30, 0.55, 0.45)
const COLOR_FALSE_LIGHT = Color(0.30, 0.85, 0.65)

# Window-view (sea panorama) — left part of the screen.
const SEA_RECT = Rect2(40, 60, 760, 360)
# Lighthouse cross-section panel — right part of the screen.
const HOUSE_RECT = Rect2(820, 60, 420, 600)
# Floor heights in the cross-section.
const LAMP_ROOM_RECT = Rect2(820, 60, 420, 200)
const QUARTERS_RECT = Rect2(820, 260, 420, 200)
const FUEL_ROOM_RECT = Rect2(820, 460, 420, 200)

# Beam pivots from lamp inside lamp room.
const LAMP_PIVOT = Vector2(1030, 160)
# Beam projects out to the sea panel.
const BEAM_LENGTH = 900.0

# ---- state ------------------------------------------------------------

var fuel: float = 100.0
var fuel_max: float = 100.0
var lens_cleanliness: float = 1.0
var damage: float = 0.0   # creature damage 0..1
var beam_angle_deg: float = 0.0   # 0 = pointing left across sea, +/- = up/down
var beam_focused: bool = false
var brightness_full: bool = true   # full vs dim mode

var current_floor: int = 0   # 0 = lamp, 1 = quarters, 2 = fuel storage

var night_time: float = 0.0
var night_duration: float = 30.0
var night_done: bool = false
var saved_ships: int = 0
var lost_ships: int = 0
var required_ships: int = 4

var ships: Array = []
var false_lights: Array = []
var tentacles: Array = []
var wreckage: Array = []
var supply_arrived: bool = false
var supply_announce_timer: float = 0.0

var rain_drops: Array = []
var wave_streaks: Array = []

# ---- node refs --------------------------------------------------------

var sea_root: Node2D = null
var ships_root: Node2D = null
var creature_root: Node2D = null
var house_root: Node2D = null
var beam_root: Node2D = null
var beam_rect: ColorRect = null
var beam_focus_rect: ColorRect = null
var lamp_glow: ColorRect = null
var fader: ColorRect = null
var lightning_overlay: ColorRect = null
var lens_grime: Array = []
var floor_panels: Array = []   # [{rect, label, content}]
var fuel_bar: ColorRect = null
var fuel_label: Label = null
var lens_bar: ColorRect = null
var lens_label: Label = null
var damage_bar: ColorRect = null
var damage_label: Label = null
var night_label: Label = null
var ship_count_label: Label = null
var time_bar: ColorRect = null
var time_label: Label = null
var feedback_label: Label = null
var feedback_timer: float = 0.0
var fuel_btn: Button = null
var lens_btn: Button = null
var repair_btn: Button = null
var dim_btn: Button = null
var floor_btns: Array = []
var status_dim_label: Label = null
var rng: RandomNumberGenerator = null

# Timing for spawns.
var ship_spawn_timer: float = 4.0
var false_light_timer: float = 8.0
var tentacle_timer: float = 12.0
var lens_dirty_timer: float = 6.0
var damage_creep_timer: float = 0.0

var fade_time: float = 0.0
var fading_out: bool = false
var fade_target_won: bool = false
var lightning_timer: float = 4.0

func _ready() -> void:
    rng = RandomNumberGenerator.new()
    rng.seed = 12345 + night * 97
    _apply_night_settings()
    _apply_overrides()
    _build_bg()
    _build_sea_panel()
    _build_house_panel()
    _build_beam()
    _build_hud()
    _build_floor_buttons()
    _build_fader()
    set_process(true)
    set_process_input(true)

func _apply_night_settings() -> void:
    if night == 1:
        night_duration = 25.0
        required_ships = 3
        fuel = 100.0
        fuel_max = 100.0
    elif night == 2:
        night_duration = 28.0
        required_ships = 4
        fuel = 80.0
        fuel_max = 100.0
    else:
        night_duration = 32.0
        required_ships = 5
        fuel = 65.0
        fuel_max = 100.0

func _apply_overrides() -> void:
    if overrides.has("fuel"):
        fuel = float(overrides.fuel)

# ---- background -------------------------------------------------------

func _build_bg() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)
    # Decorative deep frame.
    var frame = ColorRect.new()
    frame.color = Color(0.07, 0.06, 0.05)
    frame.position = Vector2(20, 40)
    frame.size = Vector2(1240, 640)
    add_child(frame)
    var inner_frame = ColorRect.new()
    inner_frame.color = Color(0.12, 0.10, 0.08)
    inner_frame.position = Vector2(28, 48)
    inner_frame.size = Vector2(1224, 624)
    add_child(inner_frame)

# ---- sea panel (window view) -----------------------------------------

func _build_sea_panel() -> void:
    sea_root = Node2D.new()
    sea_root.name = "Sea"
    add_child(sea_root)
    # Sea gradient.
    var bands = 14
    for i in range(bands):
        var t = float(i) / float(bands - 1)
        var c = COLOR_NIGHT_SKY.lerp(COLOR_SEA_BOT, t)
        var r = ColorRect.new()
        r.color = c
        r.position = SEA_RECT.position + Vector2(0, i * (SEA_RECT.size.y / bands))
        r.size = Vector2(SEA_RECT.size.x, ceil(SEA_RECT.size.y / bands) + 1)
        sea_root.add_child(r)
    # Horizon line.
    var horizon = ColorRect.new()
    horizon.color = Color(0.16, 0.20, 0.26, 0.7)
    horizon.position = SEA_RECT.position + Vector2(0, SEA_RECT.size.y * 0.32)
    horizon.size = Vector2(SEA_RECT.size.x, 2)
    sea_root.add_child(horizon)
    # Distant cliffs.
    for i in range(5):
        var c = ColorRect.new()
        c.color = Color(0.05, 0.06, 0.08)
        var x = SEA_RECT.position.x + 20 + i * 150
        var y = SEA_RECT.position.y + SEA_RECT.size.y * 0.32 - 18 - (i % 2) * 6
        c.position = Vector2(x, y)
        c.size = Vector2(120, 22 + (i % 2) * 4)
        sea_root.add_child(c)
    # Wave streaks.
    wave_streaks.clear()
    for i in range(40):
        var w = ColorRect.new()
        w.color = Color(0.30, 0.36, 0.44, 0.18)
        var y = SEA_RECT.position.y + SEA_RECT.size.y * 0.4 + (i * 7) % int(SEA_RECT.size.y * 0.55)
        var x = SEA_RECT.position.x + (i * 73) % int(SEA_RECT.size.x)
        w.position = Vector2(x, y)
        w.size = Vector2(28 + (i % 4) * 8, 2)
        sea_root.add_child(w)
        wave_streaks.append(w)
    # Foreground rocks (where ships crash).
    for spec in [[Vector2(60, 380), Vector2(80, 28)], [Vector2(160, 388), Vector2(70, 22)],
                 [Vector2(560, 384), Vector2(90, 26)], [Vector2(680, 390), Vector2(80, 22)]]:
        var r = ColorRect.new()
        r.color = Color(0.04, 0.04, 0.06)
        r.position = SEA_RECT.position + spec[0]
        r.size = spec[1]
        sea_root.add_child(r)
        var hi = ColorRect.new()
        hi.color = Color(0.10, 0.10, 0.13)
        hi.position = SEA_RECT.position + spec[0] + Vector2(8, 4)
        hi.size = Vector2(spec[1].x - 16, 4)
        sea_root.add_child(hi)
    # Window frame around the sea panel (so it reads as a window).
    var top = ColorRect.new()
    top.color = Color(0.18, 0.14, 0.10)
    top.position = SEA_RECT.position + Vector2(-8, -16)
    top.size = Vector2(SEA_RECT.size.x + 16, 16)
    sea_root.add_child(top)
    var bot = ColorRect.new()
    bot.color = Color(0.18, 0.14, 0.10)
    bot.position = SEA_RECT.position + Vector2(-8, SEA_RECT.size.y)
    bot.size = Vector2(SEA_RECT.size.x + 16, 16)
    sea_root.add_child(bot)
    var lf = ColorRect.new()
    lf.color = Color(0.18, 0.14, 0.10)
    lf.position = SEA_RECT.position + Vector2(-8, 0)
    lf.size = Vector2(8, SEA_RECT.size.y)
    sea_root.add_child(lf)
    var rg = ColorRect.new()
    rg.color = Color(0.18, 0.14, 0.10)
    rg.position = SEA_RECT.position + Vector2(SEA_RECT.size.x, 0)
    rg.size = Vector2(8, SEA_RECT.size.y)
    sea_root.add_child(rg)
    # Window cross divider.
    var vbar = ColorRect.new()
    vbar.color = Color(0.20, 0.16, 0.12)
    vbar.position = SEA_RECT.position + Vector2(SEA_RECT.size.x * 0.5 - 3, 0)
    vbar.size = Vector2(6, SEA_RECT.size.y)
    sea_root.add_child(vbar)
    # Rain in front of window.
    rain_drops.clear()
    for i in range(60):
        var d = ColorRect.new()
        d.color = COLOR_RAIN
        d.size = Vector2(2, 12)
        d.rotation = -0.3
        d.position = SEA_RECT.position + Vector2((i * 137) % int(SEA_RECT.size.x), (i * 41) % int(SEA_RECT.size.y))
        sea_root.add_child(d)
        rain_drops.append(d)
    # Lens grime overlay (dirty spots in front of view).
    lens_grime.clear()
    for i in range(8):
        var g = ColorRect.new()
        g.color = Color(0.0, 0.0, 0.0, 0.0)
        g.size = Vector2(40 + (i * 11) % 40, 40 + (i * 13) % 30)
        g.position = SEA_RECT.position + Vector2((i * 91) % int(SEA_RECT.size.x - 60), (i * 53) % int(SEA_RECT.size.y - 60))
        sea_root.add_child(g)
        lens_grime.append(g)
    # Containers above sea content.
    creature_root = Node2D.new()
    creature_root.name = "Creature"
    add_child(creature_root)
    ships_root = Node2D.new()
    ships_root.name = "Ships"
    add_child(ships_root)

# ---- house panel (cross-section) -------------------------------------

func _build_house_panel() -> void:
    house_root = Node2D.new()
    house_root.name = "House"
    add_child(house_root)
    # Outer wall.
    var wall = ColorRect.new()
    wall.color = COLOR_INTERIOR_DARK
    wall.position = HOUSE_RECT.position
    wall.size = HOUSE_RECT.size
    house_root.add_child(wall)
    var wall_inset = ColorRect.new()
    wall_inset.color = COLOR_INTERIOR_WALL
    wall_inset.position = HOUSE_RECT.position + Vector2(8, 8)
    wall_inset.size = HOUSE_RECT.size - Vector2(16, 16)
    house_root.add_child(wall_inset)
    floor_panels.clear()
    _build_lamp_room()
    _build_quarters()
    _build_fuel_room()
    # Floor dividers.
    var div1 = ColorRect.new()
    div1.color = COLOR_FLOOR_LINE
    div1.position = Vector2(HOUSE_RECT.position.x + 8, 258)
    div1.size = Vector2(HOUSE_RECT.size.x - 16, 4)
    house_root.add_child(div1)
    var div2 = ColorRect.new()
    div2.color = COLOR_FLOOR_LINE
    div2.position = Vector2(HOUSE_RECT.position.x + 8, 458)
    div2.size = Vector2(HOUSE_RECT.size.x - 16, 4)
    house_root.add_child(div2)

func _build_lamp_room() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_LAMP_ROOM
    bg.position = LAMP_ROOM_RECT.position + Vector2(8, 8)
    bg.size = LAMP_ROOM_RECT.size - Vector2(16, 12)
    house_root.add_child(bg)
    var lbl = Label.new()
    lbl.text = "LAMP ROOM"
    lbl.position = LAMP_ROOM_RECT.position + Vector2(20, 14)
    lbl.add_theme_color_override("font_color", COLOR_TEXT)
    lbl.add_theme_font_size_override("font_size", 16)
    house_root.add_child(lbl)
    # Lamp apparatus (lens housing).
    var housing = ColorRect.new()
    housing.color = Color(0.30, 0.26, 0.22)
    housing.position = Vector2(LAMP_PIVOT.x - 60, LAMP_PIVOT.y - 30)
    housing.size = Vector2(120, 60)
    house_root.add_child(housing)
    var housing_inner = ColorRect.new()
    housing_inner.color = Color(0.45, 0.38, 0.30)
    housing_inner.position = Vector2(LAMP_PIVOT.x - 50, LAMP_PIVOT.y - 22)
    housing_inner.size = Vector2(100, 44)
    house_root.add_child(housing_inner)
    lamp_glow = ColorRect.new()
    lamp_glow.color = COLOR_LAMP
    lamp_glow.position = Vector2(LAMP_PIVOT.x - 18, LAMP_PIVOT.y - 14)
    lamp_glow.size = Vector2(36, 28)
    house_root.add_child(lamp_glow)
    # Mechanism gear under lamp.
    var gear = ColorRect.new()
    gear.color = Color(0.20, 0.16, 0.13)
    gear.position = Vector2(LAMP_PIVOT.x - 30, LAMP_PIVOT.y + 32)
    gear.size = Vector2(60, 14)
    house_root.add_child(gear)
    # Window arc cutout in the wall (so beam visually escapes left).
    var slit = ColorRect.new()
    slit.color = Color(0.06, 0.07, 0.10)
    slit.position = Vector2(HOUSE_RECT.position.x + 8, LAMP_PIVOT.y - 20)
    slit.size = Vector2(8, 40)
    house_root.add_child(slit)
    floor_panels.append({"rect": LAMP_ROOM_RECT, "label": lbl})

func _build_quarters() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_QUARTERS
    bg.position = QUARTERS_RECT.position + Vector2(8, 4)
    bg.size = QUARTERS_RECT.size - Vector2(16, 8)
    house_root.add_child(bg)
    var lbl = Label.new()
    lbl.text = "QUARTERS"
    lbl.position = QUARTERS_RECT.position + Vector2(20, 10)
    lbl.add_theme_color_override("font_color", COLOR_TEXT)
    lbl.add_theme_font_size_override("font_size", 16)
    house_root.add_child(lbl)
    # Bed.
    var bed = ColorRect.new()
    bed.color = Color(0.30, 0.20, 0.18)
    bed.position = Vector2(840, 360)
    bed.size = Vector2(120, 40)
    house_root.add_child(bed)
    var pillow = ColorRect.new()
    pillow.color = Color(0.55, 0.50, 0.42)
    pillow.position = Vector2(844, 364)
    pillow.size = Vector2(36, 16)
    house_root.add_child(pillow)
    var blanket = ColorRect.new()
    blanket.color = Color(0.42, 0.18, 0.18)
    blanket.position = Vector2(884, 366)
    blanket.size = Vector2(72, 30)
    house_root.add_child(blanket)
    # Desk + lantern.
    var desk = ColorRect.new()
    desk.color = Color(0.22, 0.16, 0.12)
    desk.position = Vector2(1080, 370)
    desk.size = Vector2(120, 50)
    house_root.add_child(desk)
    var lantern = ColorRect.new()
    lantern.color = Color(0.95, 0.78, 0.45)
    lantern.position = Vector2(1130, 350)
    lantern.size = Vector2(20, 26)
    house_root.add_child(lantern)
    var lantern_h = ColorRect.new()
    lantern_h.color = Color(0.30, 0.22, 0.16)
    lantern_h.position = Vector2(1126, 346)
    lantern_h.size = Vector2(28, 6)
    house_root.add_child(lantern_h)
    # Logbook.
    var book = ColorRect.new()
    book.color = Color(0.18, 0.12, 0.10)
    book.position = Vector2(1090, 376)
    book.size = Vector2(34, 10)
    house_root.add_child(book)
    floor_panels.append({"rect": QUARTERS_RECT, "label": lbl})

func _build_fuel_room() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_FUEL_ROOM
    bg.position = FUEL_ROOM_RECT.position + Vector2(8, 4)
    bg.size = FUEL_ROOM_RECT.size - Vector2(16, 8)
    house_root.add_child(bg)
    var lbl = Label.new()
    lbl.text = "FUEL STORAGE"
    lbl.position = FUEL_ROOM_RECT.position + Vector2(20, 10)
    lbl.add_theme_color_override("font_color", COLOR_TEXT)
    lbl.add_theme_font_size_override("font_size", 16)
    house_root.add_child(lbl)
    # Fuel barrels.
    for i in range(4):
        var b = ColorRect.new()
        b.color = Color(0.30, 0.20, 0.10)
        b.position = Vector2(840 + i * 70, 540)
        b.size = Vector2(50, 80)
        house_root.add_child(b)
        var rim = ColorRect.new()
        rim.color = Color(0.45, 0.30, 0.18)
        rim.position = Vector2(840 + i * 70, 540)
        rim.size = Vector2(50, 6)
        house_root.add_child(rim)
        var rim2 = ColorRect.new()
        rim2.color = Color(0.45, 0.30, 0.18)
        rim2.position = Vector2(840 + i * 70, 614)
        rim2.size = Vector2(50, 6)
        house_root.add_child(rim2)
        var stripe = ColorRect.new()
        stripe.color = Color(0.55, 0.18, 0.10)
        stripe.position = Vector2(840 + i * 70, 575)
        stripe.size = Vector2(50, 4)
        house_root.add_child(stripe)
    # Pipe up to lamp room.
    var pipe = ColorRect.new()
    pipe.color = Color(0.22, 0.18, 0.14)
    pipe.position = Vector2(1180, 200)
    pipe.size = Vector2(8, 440)
    house_root.add_child(pipe)
    floor_panels.append({"rect": FUEL_ROOM_RECT, "label": lbl})

# ---- beam (rotating from lamp) ---------------------------------------

func _build_beam() -> void:
    beam_root = Node2D.new()
    beam_root.name = "Beam"
    beam_root.position = LAMP_PIVOT
    add_child(beam_root)
    beam_rect = ColorRect.new()
    beam_rect.color = Color(1.0, 0.92, 0.65, 0.35)
    beam_rect.size = Vector2(BEAM_LENGTH, 80)
    beam_rect.pivot_offset = Vector2(0, 40)
    beam_rect.position = Vector2(0, -40)
    beam_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    beam_rect.scale = Vector2(-1, 1)   # point left toward sea
    beam_root.add_child(beam_rect)
    # Focused beam (narrower, brighter, shown only when SPACE held).
    beam_focus_rect = ColorRect.new()
    beam_focus_rect.color = Color(1.0, 0.95, 0.70, 0.0)
    beam_focus_rect.size = Vector2(BEAM_LENGTH, 24)
    beam_focus_rect.pivot_offset = Vector2(0, 12)
    beam_focus_rect.position = Vector2(0, -12)
    beam_focus_rect.scale = Vector2(-1, 1)
    beam_focus_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    beam_root.add_child(beam_focus_rect)

# ---- HUD --------------------------------------------------------------

func _build_hud() -> void:
    # Top status bar.
    var top = ColorRect.new()
    top.color = COLOR_PANEL
    top.position = Vector2(20, 8)
    top.size = Vector2(1240, 38)
    add_child(top)
    var top_edge = ColorRect.new()
    top_edge.color = COLOR_ACCENT
    top_edge.position = Vector2(20, 44)
    top_edge.size = Vector2(1240, 2)
    add_child(top_edge)
    night_label = Label.new()
    night_label.text = "NIGHT %d / 3" % night
    night_label.position = Vector2(40, 12)
    night_label.add_theme_color_override("font_color", COLOR_TEXT)
    night_label.add_theme_font_size_override("font_size", 20)
    add_child(night_label)
    ship_count_label = Label.new()
    ship_count_label.text = "Saved %d / %d   Lost %d" % [saved_ships, required_ships, lost_ships]
    ship_count_label.position = Vector2(280, 12)
    ship_count_label.add_theme_color_override("font_color", COLOR_TEXT)
    ship_count_label.add_theme_font_size_override("font_size", 18)
    add_child(ship_count_label)
    time_label = Label.new()
    time_label.text = "DAWN IN"
    time_label.position = Vector2(640, 12)
    time_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
    time_label.add_theme_font_size_override("font_size", 16)
    add_child(time_label)
    var time_bg = ColorRect.new()
    time_bg.color = Color(0.07, 0.08, 0.10)
    time_bg.position = Vector2(720, 18)
    time_bg.size = Vector2(180, 14)
    add_child(time_bg)
    time_bar = ColorRect.new()
    time_bar.color = Color(0.55, 0.65, 0.85)
    time_bar.position = Vector2(720, 18)
    time_bar.size = Vector2(180, 14)
    add_child(time_bar)
    # Bottom control panel.
    var bot = ColorRect.new()
    bot.color = COLOR_PANEL
    bot.position = Vector2(20, 678)
    bot.size = Vector2(1240, 36)
    add_child(bot)
    var bot_edge = ColorRect.new()
    bot_edge.color = COLOR_ACCENT
    bot_edge.position = Vector2(20, 676)
    bot_edge.size = Vector2(1240, 2)
    add_child(bot_edge)
    feedback_label = Label.new()
    feedback_label.position = Vector2(40, 684)
    feedback_label.size = Vector2(1200, 24)
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.add_theme_color_override("font_color", Color(0.90, 0.78, 0.55))
    feedback_label.add_theme_font_size_override("font_size", 16)
    add_child(feedback_label)

    # Side gauges (left of sea view).
    var gauge_x = 40
    var gauge_y = 440
    var fuel_panel = ColorRect.new()
    fuel_panel.color = COLOR_PANEL_LIGHT
    fuel_panel.position = Vector2(gauge_x, gauge_y)
    fuel_panel.size = Vector2(760, 70)
    add_child(fuel_panel)
    var fuel_edge = ColorRect.new()
    fuel_edge.color = COLOR_ACCENT
    fuel_edge.position = Vector2(gauge_x, gauge_y)
    fuel_edge.size = Vector2(760, 2)
    add_child(fuel_edge)
    fuel_label = Label.new()
    fuel_label.text = "FUEL  100 / 100"
    fuel_label.position = Vector2(gauge_x + 12, gauge_y + 6)
    fuel_label.add_theme_color_override("font_color", COLOR_TEXT)
    fuel_label.add_theme_font_size_override("font_size", 16)
    add_child(fuel_label)
    var fuel_bg = ColorRect.new()
    fuel_bg.color = Color(0.07, 0.08, 0.10)
    fuel_bg.position = Vector2(gauge_x + 12, gauge_y + 32)
    fuel_bg.size = Vector2(360, 14)
    add_child(fuel_bg)
    fuel_bar = ColorRect.new()
    fuel_bar.color = Color(0.95, 0.65, 0.30)
    fuel_bar.position = Vector2(gauge_x + 12, gauge_y + 32)
    fuel_bar.size = Vector2(360, 14)
    add_child(fuel_bar)
    lens_label = Label.new()
    lens_label.text = "LENS  100%"
    lens_label.position = Vector2(gauge_x + 400, gauge_y + 6)
    lens_label.add_theme_color_override("font_color", COLOR_TEXT)
    lens_label.add_theme_font_size_override("font_size", 16)
    add_child(lens_label)
    var lens_bg = ColorRect.new()
    lens_bg.color = Color(0.07, 0.08, 0.10)
    lens_bg.position = Vector2(gauge_x + 400, gauge_y + 32)
    lens_bg.size = Vector2(160, 14)
    add_child(lens_bg)
    lens_bar = ColorRect.new()
    lens_bar.color = Color(0.55, 0.85, 0.95)
    lens_bar.position = Vector2(gauge_x + 400, gauge_y + 32)
    lens_bar.size = Vector2(160, 14)
    add_child(lens_bar)
    damage_label = Label.new()
    damage_label.text = "HULL  OK"
    damage_label.position = Vector2(gauge_x + 580, gauge_y + 6)
    damage_label.add_theme_color_override("font_color", COLOR_TEXT)
    damage_label.add_theme_font_size_override("font_size", 16)
    add_child(damage_label)
    var dmg_bg = ColorRect.new()
    dmg_bg.color = Color(0.07, 0.08, 0.10)
    dmg_bg.position = Vector2(gauge_x + 580, gauge_y + 32)
    dmg_bg.size = Vector2(160, 14)
    add_child(dmg_bg)
    damage_bar = ColorRect.new()
    damage_bar.color = Color(0.85, 0.30, 0.30)
    damage_bar.position = Vector2(gauge_x + 580, gauge_y + 32)
    damage_bar.size = Vector2(0, 14)
    add_child(damage_bar)

    # Action buttons (mouse-clickable maintenance).
    var btn_y = 530
    fuel_btn = _make_action_btn("REFUEL  LAMP", Vector2(40, btn_y), Color(0.95, 0.65, 0.30))
    fuel_btn.pressed.connect(func(): _do_refuel())
    add_child(fuel_btn)
    lens_btn = _make_action_btn("CLEAN  LENS", Vector2(220, btn_y), Color(0.55, 0.85, 0.95))
    lens_btn.pressed.connect(func(): _do_clean_lens())
    add_child(lens_btn)
    repair_btn = _make_action_btn("REPAIR  HULL", Vector2(400, btn_y), Color(0.85, 0.30, 0.30))
    repair_btn.pressed.connect(func(): _do_repair())
    add_child(repair_btn)
    dim_btn = _make_action_btn("DIM  MODE", Vector2(580, btn_y), Color(0.70, 0.70, 0.50))
    dim_btn.pressed.connect(func(): _toggle_brightness())
    add_child(dim_btn)
    status_dim_label = Label.new()
    status_dim_label.text = "MODE: BRIGHT"
    status_dim_label.position = Vector2(40, btn_y + 56)
    status_dim_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
    status_dim_label.add_theme_font_size_override("font_size", 14)
    add_child(status_dim_label)
    # Controls hint.
    var hint = Label.new()
    hint.text = "Arrows: rotate beam   |   SPACE: focus"
    hint.position = Vector2(220, btn_y + 56)
    hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
    hint.add_theme_font_size_override("font_size", 14)
    add_child(hint)

func _make_action_btn(text: String, pos: Vector2, accent: Color) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(160, 48)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL_LIGHT
    sb.border_color = accent
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    var sb_h = sb.duplicate()
    sb_h.bg_color = Color(0.20, 0.22, 0.26)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb_h)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 16)
    return b

func _build_floor_buttons() -> void:
    floor_btns.clear()
    var names = ["LAMP ROOM", "QUARTERS", "FUEL STORAGE"]
    for i in range(3):
        var b = Button.new()
        b.text = "%d  %s" % [i + 1, names[i]]
        b.position = Vector2(820, 60 + i * 200)
        b.size = Vector2(160, 28)
        var sb = StyleBoxFlat.new()
        sb.bg_color = Color(0.10, 0.10, 0.13, 0.85)
        sb.border_color = COLOR_ACCENT
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(3)
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)
        b.add_theme_stylebox_override("pressed", sb)
        b.add_theme_color_override("font_color", COLOR_TEXT)
        b.add_theme_font_size_override("font_size", 13)
        var idx = i
        b.pressed.connect(func(): _select_floor(idx))
        add_child(b)
        floor_btns.append(b)
    _select_floor(0)

func _select_floor(i: int) -> void:
    current_floor = i
    for j in range(floor_btns.size()):
        var b = floor_btns[j]
        if not is_instance_valid(b):
            continue
        var sb = b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
        sb.bg_color = Color(0.22, 0.20, 0.16, 0.95) if j == i else Color(0.10, 0.10, 0.13, 0.85)
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)
        b.add_theme_stylebox_override("pressed", sb)
    _flash("Moved to %s" % ["lamp room", "quarters", "fuel storage"][i])

# ---- fader ------------------------------------------------------------

func _build_fader() -> void:
    fader = ColorRect.new()
    fader.color = Color(0, 0, 0, 1)
    fader.size = Vector2(1280, 720)
    fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fader)
    fade_time = 0.0
    fading_out = false
    lightning_overlay = ColorRect.new()
    lightning_overlay.color = Color(0.85, 0.88, 0.95, 0.0)
    lightning_overlay.size = Vector2(1280, 720)
    lightning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(lightning_overlay)

# ---- input ------------------------------------------------------------

func _input(event: InputEvent) -> void:
    if night_done:
        return
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_SPACE:
            beam_focused = true
        if not event.pressed and event.keycode == KEY_SPACE:
            beam_focused = false
        if event.pressed and event.keycode == KEY_1:
            _select_floor(0)
        if event.pressed and event.keycode == KEY_2:
            _select_floor(1)
        if event.pressed and event.keycode == KEY_3:
            _select_floor(2)
        if event.pressed and event.keycode == KEY_D:
            _toggle_brightness()
        if event.pressed and event.keycode == KEY_F:
            _do_refuel()
        if event.pressed and event.keycode == KEY_C:
            _do_clean_lens()
        if event.pressed and event.keycode == KEY_R:
            _do_repair()

# ---- maintenance actions ---------------------------------------------

func _do_refuel() -> void:
    if night_done:
        return
    if current_floor != 2:
        _flash("Move to FUEL STORAGE first")
        return
    if fuel >= fuel_max - 1.0:
        _flash("Lamp is already full")
        return
    fuel = min(fuel_max, fuel + 25.0)
    _flash("Refueled lamp (+25)")
    _flash_color(fuel_bar, Color(1.0, 1.0, 0.6))

func _do_clean_lens() -> void:
    if night_done:
        return
    if current_floor != 0:
        _flash("Move to LAMP ROOM first")
        return
    if lens_cleanliness >= 0.99:
        _flash("Lens is already clean")
        return
    lens_cleanliness = min(1.0, lens_cleanliness + 0.25)
    _flash("Cleaned the lens (+25%)")
    _flash_color(lens_bar, Color(0.7, 1.0, 1.0))

func _do_repair() -> void:
    if night_done:
        return
    if current_floor != 1:
        _flash("Move to QUARTERS first (tools)")
        return
    if damage <= 0.01:
        _flash("Nothing to repair")
        return
    damage = max(0.0, damage - 0.30)
    _flash("Patched the structure (-30%)")
    _flash_color(damage_bar, Color(1.0, 0.8, 0.4))

func _toggle_brightness() -> void:
    if night_done:
        return
    brightness_full = not brightness_full
    if brightness_full:
        status_dim_label.text = "MODE: BRIGHT"
        dim_btn.text = "DIM  MODE"
        _flash("Lamp set to BRIGHT (drains fast, ships see clearly)")
    else:
        status_dim_label.text = "MODE: DIM"
        dim_btn.text = "BRIGHT MODE"
        _flash("Lamp set to DIM (saves fuel, ships may miss the warning)")

func _flash(text: String) -> void:
    feedback_label.text = text
    feedback_timer = 2.0

func _flash_color(node: ColorRect, c: Color) -> void:
    if node == null or not is_instance_valid(node):
        return
    var orig = node.color
    node.modulate = c
    var tw = create_tween()
    tw.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.6)

# ---- per-frame --------------------------------------------------------

func _process(dt: float) -> void:
    if fader != null and is_instance_valid(fader):
        if fading_out:
            fade_time += dt
            var k = clampf(fade_time / 0.6, 0.0, 1.0)
            fader.color.a = k
            if k >= 1.0 and not night_done:
                pass
            if k >= 1.0:
                _go_to_result()
                return
        else:
            fade_time += dt
            var k2 = clampf(fade_time / 0.6, 0.0, 1.0)
            fader.color.a = 1.0 - k2
    if night_done:
        _animate_sea(dt)
        return

    night_time += dt
    _update_beam_input(dt)
    _consume_fuel(dt)
    _drift_lens(dt)
    _drift_damage(dt)
    _spawn_phase(dt)
    _move_ships(dt)
    _move_false_lights(dt)
    _move_tentacles(dt)
    _animate_sea(dt)
    _animate_lightning(dt)
    _refresh_hud()
    _update_lens_grime()

    if feedback_timer > 0.0:
        feedback_timer -= dt
        if feedback_timer <= 0.0:
            feedback_label.text = ""

    # End-of-night.
    if saved_ships >= required_ships and not fading_out:
        _end_night(true)
    elif lost_ships >= 3 and not fading_out:
        _end_night(false)
    elif night_time >= night_duration and not fading_out:
        _end_night(saved_ships >= required_ships)

func _update_beam_input(dt: float) -> void:
    var dir = 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_UP):
        dir -= 1.0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_DOWN):
        dir += 1.0
    var speed = 60.0
    beam_angle_deg = clampf(beam_angle_deg + dir * speed * dt, -45.0, 45.0)
    if beam_root != null and is_instance_valid(beam_root):
        beam_root.rotation = deg_to_rad(180.0 + beam_angle_deg)
    var alpha = 0.4 if brightness_full else 0.18
    if fuel <= 0.0:
        alpha = 0.0
    alpha *= clampf(0.5 + 0.5 * lens_cleanliness, 0.4, 1.0)
    if beam_rect != null and is_instance_valid(beam_rect):
        beam_rect.color.a = alpha
    if beam_focus_rect != null and is_instance_valid(beam_focus_rect):
        beam_focus_rect.color.a = (0.8 if (beam_focused and fuel > 0.0) else 0.0) * (1.0 if brightness_full else 0.7)
    if lamp_glow != null and is_instance_valid(lamp_glow):
        if fuel <= 0.0:
            lamp_glow.color = COLOR_LAMP_DIM * 0.4
        else:
            lamp_glow.color = (COLOR_LAMP if brightness_full else COLOR_LAMP_DIM) * (0.85 + 0.15 * sin(night_time * 6.0))

func _consume_fuel(dt: float) -> void:
    var rate = 1.4 if brightness_full else 0.7
    if beam_focused:
        rate += 1.2
    rate *= 1.0 + 0.15 * (night - 1)
    fuel = max(0.0, fuel - rate * dt)

func _drift_lens(dt: float) -> void:
    var rate = 0.04 + 0.02 * (night - 1)
    lens_cleanliness = max(0.0, lens_cleanliness - rate * dt)
    lens_dirty_timer -= dt

func _drift_damage(dt: float) -> void:
    damage_creep_timer += dt
    # Tentacles attached to dock add damage.
    var attached = 0
    for t in tentacles:
        if t.attached:
            attached += 1
    if attached > 0:
        damage = min(1.0, damage + 0.04 * attached * dt)

func _spawn_phase(_dt: float) -> void:
    var t = night_time
    ship_spawn_timer -= _dt
    false_light_timer -= _dt
    tentacle_timer -= _dt
    if ship_spawn_timer <= 0.0:
        _spawn_ship()
        var interval = 7.0 - (night - 1) * 1.2
        if night == 3:
            interval = 4.0
        ship_spawn_timer = interval + rng.randf_range(-0.6, 0.6)
    if false_light_timer <= 0.0:
        _spawn_false_light()
        var interval = 11.0 - (night - 1) * 2.0
        false_light_timer = max(4.0, interval) + rng.randf_range(-1.0, 1.0)
    if tentacle_timer <= 0.0:
        _spawn_tentacle()
        var interval = 14.0 - (night - 1) * 3.0
        tentacle_timer = max(5.0, interval) + rng.randf_range(-1.5, 1.5)
    if not supply_arrived and t > night_duration * 0.5:
        supply_arrived = true
        fuel = min(fuel_max, fuel + 30.0 - (night - 1) * 8.0)
        _flash("SUPPLY BOAT delivered fuel (+%d)" % int(30 - (night - 1) * 8))

# ---- ships -----------------------------------------------------------

func _spawn_ship() -> void:
    # Spawn a ship at the horizon. It has a target safe-harbor x and a current
    # heading. The beam can nudge the heading; false lights pull it toward
    # the rocks; tentacles slow it down.
    var horizon_y = SEA_RECT.position.y + SEA_RECT.size.y * 0.35
    var x = SEA_RECT.position.x + rng.randf_range(60, SEA_RECT.size.x - 60)
    var ship_root = Node2D.new()
    ship_root.position = Vector2(x, horizon_y)
    ships_root.add_child(ship_root)
    # Hull.
    var hull = ColorRect.new()
    hull.color = Color(0.20, 0.18, 0.16)
    hull.position = Vector2(-10, -3)
    hull.size = Vector2(20, 7)
    ship_root.add_child(hull)
    # Light.
    var lamp = ColorRect.new()
    lamp.color = Color(1.0, 0.85, 0.55)
    lamp.position = Vector2(-2, -8)
    lamp.size = Vector2(4, 4)
    ship_root.add_child(lamp)
    # Mast.
    var mast = ColorRect.new()
    mast.color = Color(0.20, 0.18, 0.16)
    mast.position = Vector2(-1, -8)
    mast.size = Vector2(2, 6)
    ship_root.add_child(mast)
    var ship = {
        "root": ship_root, "hull": hull, "lamp": lamp,
        "x": x, "y": horizon_y,
        "heading_x": SEA_RECT.position.x + SEA_RECT.size.x * 0.5,   # safe harbor
        "speed": 18.0 + rng.randf_range(-3.0, 3.0) + (night - 1) * 4.0,
        "dead": false, "alive": true, "saved": false, "scale": 0.4,
    }
    ships.append(ship)

func _move_ships(dt: float) -> void:
    var to_remove = []
    var beam_rad = deg_to_rad(beam_angle_deg)
    var safe_x = SEA_RECT.position.x + SEA_RECT.size.x * 0.5
    var rocks_y = SEA_RECT.position.y + SEA_RECT.size.y * 0.92
    for s in ships:
        if not s.alive:
            continue
        # Distance from ship to where the beam is sweeping (project beam onto
        # the sea panel: the beam leaves the lamp pointing left and tilts
        # by beam_angle_deg). Approximate the beam's hit-x at the ship's y.
        var ship_node_pos = s.root.position
        var dy_from_lamp = ship_node_pos.y - LAMP_PIVOT.y
        var beam_hit_x = LAMP_PIVOT.x + dy_from_lamp / max(0.01, tan(beam_rad)) if abs(beam_rad) > 0.01 else SEA_RECT.position.x - 200
        # If beam is roughly horizontal, treat hit_x as far-left.
        if abs(beam_rad) < 0.05:
            beam_hit_x = SEA_RECT.position.x - 200
        var beam_dx = ship_node_pos.x - beam_hit_x
        var lit = false
        var beam_alive = fuel > 0.0
        if beam_alive:
            var radius = 90.0 if brightness_full else 50.0
            if beam_focused:
                radius = 140.0
            radius *= 0.5 + 0.5 * lens_cleanliness
            if abs(beam_dx) < radius and ship_node_pos.x > LAMP_PIVOT.x - 1000 and ship_node_pos.x < LAMP_PIVOT.x:
                lit = true
        # Decide pull direction.
        var pull_x = 0.0
        var nearest_lure = _nearest_false_light(ship_node_pos)
        if lit:
            # Beam guides ship toward safe harbor.
            pull_x = sign(safe_x - ship_node_pos.x) * 30.0
            s.lamp.color = Color(1.0, 0.95, 0.6)
        elif nearest_lure != null and nearest_lure.distance < 130.0:
            # False light pulls them toward rocks.
            pull_x = sign(nearest_lure.lure.x - ship_node_pos.x) * 22.0
            s.lamp.color = Color(0.6, 0.95, 0.7)
        else:
            # No guidance, drift slightly toward nearest rock cluster.
            pull_x = (sign(safe_x - ship_node_pos.x) * -10.0)
            s.lamp.color = Color(0.85, 0.50, 0.30)
        s.x += pull_x * dt
        s.y += s.speed * dt * 0.55
        s.scale = clampf(0.4 + (s.y - SEA_RECT.position.y - SEA_RECT.size.y * 0.35) / (SEA_RECT.size.y * 0.55), 0.4, 1.4)
        s.root.position = Vector2(s.x, s.y)
        s.root.scale = Vector2(s.scale, s.scale)
        # Reached bottom: classify as saved or wrecked.
        if s.y >= rocks_y:
            var dist_to_safe = abs(s.x - safe_x)
            var safe_window = 90.0
            if dist_to_safe <= safe_window:
                s.saved = true
                saved_ships += 1
                _flash("Ship guided to harbor (+1)")
                _spark(Vector2(s.x, s.y), Color(0.6, 1.0, 0.7))
                to_remove.append(s)
            else:
                lost_ships += 1
                _spawn_wreck(Vector2(s.x, s.y))
                _flash("A SHIP HAS WRECKED")
                to_remove.append(s)
            s.alive = false
        # Tentacle drag — if a tentacle is near, slow ship.
        for tn in tentacles:
            if not tn.attached:
                continue
            var tn_pos = Vector2(tn.x, tn.y)
            if tn_pos.distance_to(ship_node_pos) < 40:
                s.speed = max(8.0, s.speed - dt * 5.0)
    for s in to_remove:
        if is_instance_valid(s.root):
            s.root.queue_free()
        ships.erase(s)

func _spawn_wreck(at: Vector2) -> void:
    var w = ColorRect.new()
    w.color = Color(0.10, 0.08, 0.07)
    w.position = at - Vector2(12, 4)
    w.size = Vector2(24, 6)
    sea_root.add_child(w)
    wreckage.append(w)
    var glow = ColorRect.new()
    glow.color = Color(0.85, 0.30, 0.20, 0.5)
    glow.position = at - Vector2(8, -2)
    glow.size = Vector2(16, 3)
    sea_root.add_child(glow)
    wreckage.append(glow)

# ---- false lights ----------------------------------------------------

func _spawn_false_light() -> void:
    var x = SEA_RECT.position.x + rng.randf_range(40, SEA_RECT.size.x - 40)
    var y = SEA_RECT.position.y + SEA_RECT.size.y * rng.randf_range(0.45, 0.7)
    var lure_root = Node2D.new()
    lure_root.position = Vector2(x, y)
    creature_root.add_child(lure_root)
    var glow = ColorRect.new()
    glow.color = COLOR_FALSE_LIGHT
    glow.position = Vector2(-6, -6)
    glow.size = Vector2(12, 12)
    lure_root.add_child(glow)
    var halo = ColorRect.new()
    halo.color = Color(0.40, 0.95, 0.75, 0.35)
    halo.position = Vector2(-14, -14)
    halo.size = Vector2(28, 28)
    lure_root.add_child(halo)
    false_lights.append({"root": lure_root, "glow": glow, "halo": halo,
                         "x": x, "y": y, "life": 9.0, "phase": rng.randf() * TAU})

func _move_false_lights(dt: float) -> void:
    var to_remove = []
    var beam_rad = deg_to_rad(beam_angle_deg)
    var beam_alive = fuel > 0.0
    for f in false_lights:
        f.life -= dt
        f.phase += dt * 3.0
        var pulse = 0.6 + 0.4 * sin(f.phase)
        f.glow.color = COLOR_FALSE_LIGHT * pulse
        f.halo.color = Color(0.40, 0.95, 0.75, 0.30 * pulse)
        f.root.position = Vector2(f.x + sin(f.phase * 0.5) * 8.0, f.y + cos(f.phase * 0.7) * 4.0)
        # Focused beam dispels lures it hits.
        if beam_focused and beam_alive:
            var dy = f.y - LAMP_PIVOT.y
            var beam_hit_x = LAMP_PIVOT.x + dy / max(0.01, tan(beam_rad)) if abs(beam_rad) > 0.01 else SEA_RECT.position.x - 200
            if abs(f.x - beam_hit_x) < 60.0 and f.x < LAMP_PIVOT.x:
                f.life = min(f.life, 0.4)
        if f.life <= 0.0:
            to_remove.append(f)
    for f in to_remove:
        _spark(Vector2(f.x, f.y), Color(0.40, 0.85, 0.65))
        if is_instance_valid(f.root):
            f.root.queue_free()
        false_lights.erase(f)

func _nearest_false_light(pos: Vector2):
    var best = null
    var best_d = 1e9
    for f in false_lights:
        var d = Vector2(f.x, f.y).distance_to(pos)
        if d < best_d:
            best_d = d
            best = f
    if best == null:
        return null
    return {"lure": Vector2(best.x, best.y), "distance": best_d}

# ---- tentacles -------------------------------------------------------

func _spawn_tentacle() -> void:
    var x = SEA_RECT.position.x + rng.randf_range(40, SEA_RECT.size.x - 40)
    var y = SEA_RECT.position.y + SEA_RECT.size.y * 0.85
    var t_root = Node2D.new()
    t_root.position = Vector2(x, y)
    creature_root.add_child(t_root)
    var segs = []
    for i in range(6):
        var seg = ColorRect.new()
        seg.color = COLOR_CREATURE * (1.0 - i * 0.08)
        seg.position = Vector2(-4, -i * 10)
        seg.size = Vector2(8 - i * 0.5, 12)
        t_root.add_child(seg)
        segs.append(seg)
    var tip = ColorRect.new()
    tip.color = Color(0.40, 0.85, 0.65)
    tip.position = Vector2(-3, -segs.size() * 10 - 6)
    tip.size = Vector2(6, 6)
    t_root.add_child(tip)
    tentacles.append({"root": t_root, "segs": segs, "tip": tip,
                      "x": x, "y": y, "life": 10.0, "phase": rng.randf() * TAU,
                      "attached": rng.randf() < 0.5})

func _move_tentacles(dt: float) -> void:
    var to_remove = []
    var beam_rad = deg_to_rad(beam_angle_deg)
    var beam_alive = fuel > 0.0
    for t in tentacles:
        t.life -= dt
        t.phase += dt * 2.5
        for i in range(t.segs.size()):
            var seg = t.segs[i]
            var sway = sin(t.phase + i * 0.6) * (1.0 + i * 0.3)
            seg.position = Vector2(-4 + sway, -i * 10)
        t.tip.position = Vector2(-3 + sin(t.phase + t.segs.size() * 0.6) * (1.0 + t.segs.size() * 0.3),
                                  -t.segs.size() * 10 - 6)
        # Focused beam burns tentacles.
        if beam_focused and beam_alive:
            var dy = t.y - LAMP_PIVOT.y
            var beam_hit_x = LAMP_PIVOT.x + dy / max(0.01, tan(beam_rad)) if abs(beam_rad) > 0.01 else SEA_RECT.position.x - 200
            if abs(t.x - beam_hit_x) < 60.0 and t.x < LAMP_PIVOT.x:
                t.life = min(t.life, 0.4)
        if t.life <= 0.0:
            to_remove.append(t)
    for t in to_remove:
        _spark(Vector2(t.x, t.y - 30), Color(0.85, 0.30, 0.30))
        if is_instance_valid(t.root):
            t.root.queue_free()
        tentacles.erase(t)

# ---- visuals ----------------------------------------------------------

func _animate_sea(dt: float) -> void:
    for d in rain_drops:
        if not is_instance_valid(d):
            continue
        d.position += Vector2(-200.0 * dt, 540.0 * dt)
        if d.position.y > SEA_RECT.position.y + SEA_RECT.size.y:
            d.position.y = SEA_RECT.position.y - 10
            d.position.x = SEA_RECT.position.x + rng.randf_range(0, SEA_RECT.size.x)
        if d.position.x < SEA_RECT.position.x - 40:
            d.position.x = SEA_RECT.position.x + SEA_RECT.size.x
    for w in wave_streaks:
        if not is_instance_valid(w):
            continue
        w.position.x -= 25.0 * dt
        if w.position.x < SEA_RECT.position.x - 80:
            w.position.x = SEA_RECT.position.x + SEA_RECT.size.x
            w.position.y = SEA_RECT.position.y + SEA_RECT.size.y * 0.4 + rng.randf_range(0, SEA_RECT.size.y * 0.5)

func _animate_lightning(dt: float) -> void:
    lightning_timer -= dt
    if lightning_timer <= 0.0:
        var base = 5.0 - (night - 1) * 1.0
        lightning_timer = base + rng.randf_range(-1.0, 1.0)
        if lightning_overlay != null and is_instance_valid(lightning_overlay):
            lightning_overlay.color = Color(0.85, 0.88, 0.95, 0.55)
    if lightning_overlay != null and is_instance_valid(lightning_overlay):
        var a = lightning_overlay.color.a
        a = max(0.0, a - dt * 1.4)
        lightning_overlay.color.a = a

func _update_lens_grime() -> void:
    var alpha = (1.0 - lens_cleanliness) * 0.55
    for g in lens_grime:
        if not is_instance_valid(g):
            continue
        g.color = Color(0.05, 0.06, 0.08, alpha)

func _refresh_hud() -> void:
    var fuel_pct = fuel / fuel_max
    fuel_bar.size = Vector2(360.0 * fuel_pct, 14)
    fuel_label.text = "FUEL  %d / %d" % [int(fuel), int(fuel_max)]
    if fuel <= 20.0:
        fuel_bar.color = Color(0.95, 0.30, 0.20)
        fuel_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55))
    else:
        fuel_bar.color = Color(0.95, 0.65, 0.30)
        fuel_label.add_theme_color_override("font_color", COLOR_TEXT)
    lens_bar.size = Vector2(160.0 * lens_cleanliness, 14)
    lens_label.text = "LENS  %d%%" % int(lens_cleanliness * 100)
    damage_bar.size = Vector2(160.0 * damage, 14)
    damage_label.text = "HULL  %s" % ("OK" if damage < 0.05 else "%d%%" % int(damage * 100))
    ship_count_label.text = "Saved %d / %d   Lost %d" % [saved_ships, required_ships, lost_ships]
    night_label.text = "NIGHT %d / 3" % night
    var time_remaining = max(0.0, night_duration - night_time)
    time_bar.size = Vector2(180.0 * (time_remaining / night_duration), 14)
    time_label.text = "DAWN IN  %0d s" % int(time_remaining)

# ---- end of night -----------------------------------------------------

func _end_night(won: bool) -> void:
    if night_done:
        return
    night_done = true
    fading_out = true
    fade_target_won = won
    fade_time = 0.0

func _go_to_result() -> void:
    if main == null:
        return
    if fade_target_won and night < 3:
        main._enter_game(night + 1)
    else:
        main._enter_result(night, fade_target_won, saved_ships, lost_ships)

# ---- spark fx ---------------------------------------------------------

func _spark(at: Vector2, color: Color) -> void:
    for j in range(5):
        var s = ColorRect.new()
        s.color = color
        s.size = Vector2(5, 5)
        s.position = at - Vector2(2, 2)
        creature_root.add_child(s)
        var angle = rng.randf() * TAU
        var dist = 12.0 + rng.randf() * 12.0
        var target = at + Vector2(cos(angle), sin(angle)) * dist
        _animate_spark(s, target)

func _animate_spark(node: ColorRect, target: Vector2) -> void:
    var t = 0.0
    var dur = 0.3
    var start = node.position
    while t < dur:
        await get_tree().process_frame
        t += get_process_delta_time()
        if not is_instance_valid(node):
            return
        var k = clampf(t / dur, 0, 1)
        node.position = start.lerp(target, k)
        node.modulate.a = 1.0 - k
    if is_instance_valid(node):
        node.queue_free()
