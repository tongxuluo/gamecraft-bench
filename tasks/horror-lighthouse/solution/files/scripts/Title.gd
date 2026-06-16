extends Node2D

var main: Node = null

const COLOR_SKY_TOP = Color(0.06, 0.08, 0.12)
const COLOR_SKY_MID = Color(0.10, 0.13, 0.18)
const COLOR_SEA_TOP = Color(0.08, 0.10, 0.14)
const COLOR_SEA_BOT = Color(0.03, 0.04, 0.06)
const COLOR_LAMP = Color(1.00, 0.86, 0.55)
const COLOR_LIGHTHOUSE_DARK = Color(0.16, 0.16, 0.19)
const COLOR_LIGHTHOUSE_LIGHT = Color(0.28, 0.28, 0.32)
const COLOR_TEXT = Color(0.86, 0.84, 0.78)
const COLOR_PANEL = Color(0.12, 0.14, 0.18)
const COLOR_ACCENT = Color(0.55, 0.60, 0.66)
const COLOR_RAIN = Color(0.65, 0.70, 0.78, 0.45)

var beam: ColorRect = null
var beam_lamp: ColorRect = null
var beam_angle: float = 0.0
var fader: ColorRect = null
var fade_time: float = 0.0
var fade_dur: float = 0.6
var fading_out: bool = false
var rain_drops: Array = []
var lightning_timer: float = 2.0
var lightning_flash: ColorRect = null

func _ready() -> void:
    _build_sky()
    _build_sea()
    _build_clouds()
    _build_rocks()
    _build_lighthouse()
    _build_rain()
    _build_lightning_overlay()
    _build_title_text()
    _build_buttons()
    _build_fader_in()
    set_process(true)

func _build_sky() -> void:
    # Vertical gradient simulated with stacked bands.
    var bands = 16
    for i in range(bands):
        var t = float(i) / float(bands - 1)
        var c = COLOR_SKY_TOP.lerp(COLOR_SKY_MID, t)
        var r = ColorRect.new()
        r.color = c
        r.position = Vector2(0, i * (440.0 / bands))
        r.size = Vector2(1280, ceil(440.0 / bands) + 1)
        add_child(r)

func _build_sea() -> void:
    var bands = 12
    for i in range(bands):
        var t = float(i) / float(bands - 1)
        var c = COLOR_SEA_TOP.lerp(COLOR_SEA_BOT, t)
        var r = ColorRect.new()
        r.color = c
        r.position = Vector2(0, 440 + i * (280.0 / bands))
        r.size = Vector2(1280, ceil(280.0 / bands) + 1)
        add_child(r)
    # Wave streaks.
    for i in range(40):
        var w = ColorRect.new()
        w.color = Color(0.30, 0.36, 0.44, 0.22)
        var y = 460 + (i * 7) % 250
        var x = (i * 113) % 1280
        w.position = Vector2(x, y)
        w.size = Vector2(40 + (i % 5) * 12, 2)
        add_child(w)
    # Horizon line glow.
    var horizon = ColorRect.new()
    horizon.color = Color(0.18, 0.22, 0.28, 0.6)
    horizon.position = Vector2(0, 438)
    horizon.size = Vector2(1280, 2)
    add_child(horizon)

func _build_clouds() -> void:
    var positions = [
        Vector2(80, 120), Vector2(360, 80), Vector2(680, 140),
        Vector2(950, 70), Vector2(220, 220), Vector2(820, 230),
    ]
    var sizes = [
        Vector2(260, 60), Vector2(320, 70), Vector2(280, 50),
        Vector2(300, 80), Vector2(220, 50), Vector2(260, 60),
    ]
    for i in range(positions.size()):
        var c = ColorRect.new()
        c.color = Color(0.05, 0.06, 0.09, 0.85)
        c.position = positions[i]
        c.size = sizes[i]
        add_child(c)
        var c2 = ColorRect.new()
        c2.color = Color(0.10, 0.12, 0.16, 0.55)
        c2.position = positions[i] + Vector2(20, -10)
        c2.size = sizes[i] * Vector2(0.7, 0.8)
        add_child(c2)

func _build_rocks() -> void:
    var rock_specs = [
        [Vector2(60, 600), Vector2(180, 70)],
        [Vector2(200, 620), Vector2(140, 50)],
        [Vector2(940, 610), Vector2(180, 60)],
        [Vector2(1100, 600), Vector2(160, 70)],
    ]
    for spec in rock_specs:
        var r = ColorRect.new()
        r.color = Color(0.05, 0.05, 0.07)
        r.position = spec[0]
        r.size = spec[1]
        add_child(r)
        var hi = ColorRect.new()
        hi.color = Color(0.12, 0.13, 0.15)
        hi.position = spec[0] + Vector2(8, 4)
        hi.size = Vector2(spec[1].x - 16, 6)
        add_child(hi)

func _build_lighthouse() -> void:
    var base_x = 880
    var base_y = 540
    # Cliff under lighthouse.
    var cliff = ColorRect.new()
    cliff.color = Color(0.06, 0.07, 0.09)
    cliff.position = Vector2(base_x - 60, base_y + 40)
    cliff.size = Vector2(220, 140)
    add_child(cliff)
    # Tower body (tapered, simulated with two stacked rects).
    var tower_lo = ColorRect.new()
    tower_lo.color = COLOR_LIGHTHOUSE_DARK
    tower_lo.position = Vector2(base_x - 30, base_y - 40)
    tower_lo.size = Vector2(110, 100)
    add_child(tower_lo)
    var tower_hi = ColorRect.new()
    tower_hi.color = COLOR_LIGHTHOUSE_LIGHT
    tower_hi.position = Vector2(base_x - 10, base_y - 160)
    tower_hi.size = Vector2(70, 130)
    add_child(tower_hi)
    # Red bands on the tower.
    for y in [base_y - 130, base_y - 80]:
        var band = ColorRect.new()
        band.color = Color(0.40, 0.10, 0.10)
        band.position = Vector2(base_x - 10, y)
        band.size = Vector2(70, 18)
        add_child(band)
    # Lamp room.
    var lamp_room = ColorRect.new()
    lamp_room.color = Color(0.14, 0.14, 0.16)
    lamp_room.position = Vector2(base_x - 18, base_y - 200)
    lamp_room.size = Vector2(86, 50)
    add_child(lamp_room)
    var lamp_glow = ColorRect.new()
    lamp_glow.color = COLOR_LAMP
    lamp_glow.position = Vector2(base_x + 5, base_y - 188)
    lamp_glow.size = Vector2(40, 28)
    add_child(lamp_glow)
    var roof = ColorRect.new()
    roof.color = Color(0.30, 0.10, 0.10)
    roof.position = Vector2(base_x - 22, base_y - 220)
    roof.size = Vector2(94, 22)
    add_child(roof)
    var spire = ColorRect.new()
    spire.color = Color(0.25, 0.27, 0.30)
    spire.position = Vector2(base_x + 22, base_y - 240)
    spire.size = Vector2(6, 22)
    add_child(spire)
    beam_lamp = lamp_glow
    # Beam: a long thin rect rotated around lamp center.
    beam = ColorRect.new()
    beam.color = Color(1.0, 0.92, 0.65, 0.32)
    beam.size = Vector2(1100, 90)
    beam.pivot_offset = Vector2(0, 45)
    beam.position = Vector2(base_x + 25, base_y - 174)
    beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(beam)

func _build_rain() -> void:
    rain_drops.clear()
    for i in range(60):
        var d = ColorRect.new()
        d.color = COLOR_RAIN
        d.size = Vector2(2, 14)
        d.rotation = -0.35
        d.position = Vector2((i * 137) % 1280, (i * 41) % 720)
        add_child(d)
        rain_drops.append(d)

func _build_lightning_overlay() -> void:
    lightning_flash = ColorRect.new()
    lightning_flash.color = Color(0.85, 0.88, 0.95, 0.0)
    lightning_flash.size = Vector2(1280, 720)
    lightning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(lightning_flash)

func _build_title_text() -> void:
    # Weathered serif title (Godot default + outline + tracking via spacing).
    var title = Label.new()
    title.text = "T H E   K E E P E R ' S   L A M P"
    title.position = Vector2(0, 60)
    title.size = Vector2(1280, 80)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.70))
    title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
    title.add_theme_constant_override("outline_size", 8)
    title.add_theme_font_size_override("font_size", 56)
    add_child(title)
    var subtitle = Label.new()
    subtitle.text = "a watch in three nights"
    subtitle.position = Vector2(0, 130)
    subtitle.size = Vector2(1280, 40)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.70, 0.66, 0.56))
    subtitle.add_theme_font_size_override("font_size", 22)
    add_child(subtitle)
    var hint = Label.new()
    hint.text = "Arrow keys rotate the beam   |   Space focuses   |   Click panels to maintain"
    hint.position = Vector2(0, 670)
    hint.size = Vector2(1280, 28)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.60, 0.58, 0.50))
    hint.add_theme_font_size_override("font_size", 16)
    add_child(hint)

func _build_buttons() -> void:
    var btn = _make_button("BEGIN  THE  WATCH", Vector2(440, 340))
    btn.pressed.connect(func(): _go_to_game())
    add_child(btn)

func _make_button(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(400, 64)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_ACCENT
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    var sb_h = sb.duplicate()
    sb_h.bg_color = Color(0.18, 0.20, 0.24)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb_h)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72))
    b.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    b.add_theme_constant_override("outline_size", 4)
    b.add_theme_font_size_override("font_size", 28)
    return b

func _build_fader_in() -> void:
    fader = ColorRect.new()
    fader.color = Color(0, 0, 0, 1)
    fader.size = Vector2(1280, 720)
    fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fader)
    fade_time = 0.0
    fading_out = false

func _go_to_game() -> void:
    if fading_out:
        return
    fading_out = true
    fade_time = 0.0
    if fader == null or not is_instance_valid(fader):
        fader = ColorRect.new()
        fader.color = Color(0, 0, 0, 0)
        fader.size = Vector2(1280, 720)
        fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(fader)

func _process(dt: float) -> void:
    # Sweeping beam.
    beam_angle += dt * 0.35
    if beam != null and is_instance_valid(beam):
        var swing = sin(beam_angle) * 0.55
        beam.rotation = -0.05 + swing
        # Flicker.
        var flick = 0.32 + 0.08 * sin(beam_angle * 7.3)
        beam.color = Color(1.0, 0.92, 0.65, flick)
    if beam_lamp != null and is_instance_valid(beam_lamp):
        var pulse = 0.85 + 0.15 * sin(beam_angle * 4.0)
        beam_lamp.color = Color(1.0, 0.86, 0.55) * pulse
    # Rain.
    for d in rain_drops:
        if not is_instance_valid(d):
            continue
        d.position += Vector2(-180.0 * dt, 480.0 * dt)
        if d.position.y > 720:
            d.position.y = -20
            d.position.x = randf() * 1280.0 + 200.0
        if d.position.x < -40:
            d.position.x = 1280.0 + 40.0
    # Lightning flashes.
    lightning_timer -= dt
    if lightning_timer <= 0.0:
        lightning_timer = 3.0 + randf() * 4.0
        if lightning_flash != null and is_instance_valid(lightning_flash):
            lightning_flash.color = Color(0.85, 0.88, 0.95, 0.7)
    if lightning_flash != null and is_instance_valid(lightning_flash):
        var a = lightning_flash.color.a
        a = max(0.0, a - dt * 1.4)
        lightning_flash.color.a = a
    # Fade.
    if fader == null or not is_instance_valid(fader):
        return
    fade_time += dt
    if fading_out:
        var k = clampf(fade_time / fade_dur, 0.0, 1.0)
        fader.color.a = k
        if k >= 1.0:
            main._enter_game(1)
    else:
        var k2 = clampf(fade_time / fade_dur, 0.0, 1.0)
        fader.color.a = 1.0 - k2
