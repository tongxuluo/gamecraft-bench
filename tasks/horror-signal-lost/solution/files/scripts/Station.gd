extends Node2D

var main: Node = null

const COLOR_BG = Color(0.03, 0.04, 0.05)
const COLOR_DESK = Color(0.12, 0.10, 0.08)
const COLOR_RADIO = Color(0.08, 0.10, 0.08)
const COLOR_GLOW = Color(0.30, 0.85, 0.40)
const COLOR_GLOW_DIM = Color(0.15, 0.40, 0.20)
const COLOR_TEXT = Color(0.75, 0.90, 0.75)
const COLOR_WARN = Color(0.85, 0.30, 0.30)
const COLOR_MAP = Color(0.16, 0.14, 0.12)
const COLOR_PIN = Color(0.90, 0.30, 0.30)
const COLOR_PANEL = Color(0.08, 0.10, 0.08)

const SIGNALS_DATA = [
    {"freq": 0.15, "name": "OUTPOST DELTA", "coords": Vector2(180, 140),
     "text": "...requesting evac... something in the water..."},
    {"freq": 0.35, "name": "VESSEL KRAIT", "coords": Vector2(320, 220),
     "text": "...engines dead... crew missing... hull breached from inside..."},
    {"freq": 0.55, "name": "STATION ECHO", "coords": Vector2(240, 300),
     "text": "...do not respond to signal at 0.72... it mimics..."},
    {"freq": 0.72, "name": "UNKNOWN SOURCE", "coords": Vector2(400, 180),
     "text": "...we see you... we are close... turn off the light..."},
    {"freq": 0.90, "name": "LIGHTHOUSE 7", "coords": Vector2(360, 340),
     "text": "...final broadcast... the signal IS the entity... stop listening..."},
]

var dial_value: float = 0.5
var locked_signal_idx: int = -1
var playing: bool = false
var battery_drain_rate: float = 2.0
var jamming: bool = false
var jam_timer: float = 0.0
var jam_escape_window: float = 0.0

var dial_slider: HSlider = null
var freq_label: Label = null
var transcript_label: Label = null
var battery_bar: ColorRect = null
var battery_label: Label = null
var signal_label: Label = null
var status_label: Label = null
var map_pins: Array = []
var pin_nodes: Array = []
var progress_label: Label = null
var jam_overlay: ColorRect = null

var rng: RandomNumberGenerator = null
var next_jam_time: float = 8.0
var elapsed: float = 0.0

func _ready() -> void:
    rng = RandomNumberGenerator.new()
    rng.seed = 99
    _build_bg()
    _build_radio_panel()
    _build_map()
    _build_hud()
    _build_jam_overlay()
    set_process(true)

func _build_bg() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)
    # Desk surface.
    var desk = ColorRect.new()
    desk.color = COLOR_DESK
    desk.position = Vector2(0, 500)
    desk.size = Vector2(1280, 220)
    add_child(desk)
    # Window (dark, ominous).
    var window = ColorRect.new()
    window.color = Color(0.02, 0.02, 0.04)
    window.position = Vector2(900, 40)
    window.size = Vector2(340, 200)
    add_child(window)
    var window_frame = ColorRect.new()
    window_frame.color = Color(0.18, 0.15, 0.12)
    window_frame.position = Vector2(898, 38)
    window_frame.size = Vector2(344, 204)
    window_frame.z_index = -1
    add_child(window_frame)

func _build_radio_panel() -> void:
    # Radio equipment block.
    var radio_bg = ColorRect.new()
    radio_bg.color = COLOR_RADIO
    radio_bg.position = Vector2(40, 280)
    radio_bg.size = Vector2(500, 200)
    add_child(radio_bg)
    var radio_border = ColorRect.new()
    radio_border.color = COLOR_GLOW_DIM
    radio_border.position = Vector2(38, 278)
    radio_border.size = Vector2(504, 204)
    radio_border.z_index = -1
    add_child(radio_border)

    # Frequency dial (HSlider).
    dial_slider = HSlider.new()
    dial_slider.min_value = 0.0
    dial_slider.max_value = 1.0
    dial_slider.step = 0.01
    dial_slider.value = dial_value
    dial_slider.position = Vector2(60, 340)
    dial_slider.size = Vector2(460, 30)
    dial_slider.value_changed.connect(func(v: float): _on_dial_changed(v))
    add_child(dial_slider)

    freq_label = Label.new()
    freq_label.text = "FREQ: %.2f MHz" % (dial_value * 108.0)
    freq_label.position = Vector2(60, 290)
    freq_label.size = Vector2(460, 30)
    freq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    freq_label.add_theme_color_override("font_color", COLOR_GLOW)
    freq_label.add_theme_font_size_override("font_size", 22)
    add_child(freq_label)

    signal_label = Label.new()
    signal_label.text = "-- NO SIGNAL --"
    signal_label.position = Vector2(60, 380)
    signal_label.size = Vector2(460, 30)
    signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    signal_label.add_theme_color_override("font_color", COLOR_TEXT)
    signal_label.add_theme_font_size_override("font_size", 18)
    add_child(signal_label)

    transcript_label = Label.new()
    transcript_label.text = ""
    transcript_label.position = Vector2(60, 420)
    transcript_label.size = Vector2(460, 50)
    transcript_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    transcript_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    transcript_label.add_theme_color_override("font_color", Color(0.60, 0.75, 0.60))
    transcript_label.add_theme_font_size_override("font_size", 16)
    add_child(transcript_label)

    # Mark / Pin button.
    var mark_btn = _make_button("PLACE PIN", Vector2(180, 520))
    mark_btn.pressed.connect(func(): _on_place_pin())
    add_child(mark_btn)

func _build_map() -> void:
    # Map panel on the right.
    var map_bg = ColorRect.new()
    map_bg.color = COLOR_MAP
    map_bg.position = Vector2(600, 280)
    map_bg.size = Vector2(440, 340)
    add_child(map_bg)
    var map_border = ColorRect.new()
    map_border.color = Color(0.30, 0.25, 0.18)
    map_border.position = Vector2(598, 278)
    map_border.size = Vector2(444, 344)
    map_border.z_index = -1
    add_child(map_border)
    var map_title = Label.new()
    map_title.text = "SECTOR MAP"
    map_title.position = Vector2(600, 284)
    map_title.size = Vector2(440, 24)
    map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_title.add_theme_color_override("font_color", Color(0.50, 0.45, 0.35))
    map_title.add_theme_font_size_override("font_size", 16)
    add_child(map_title)
    # Grid lines on map.
    for i in range(5):
        var h = ColorRect.new()
        h.color = Color(0.22, 0.18, 0.14)
        h.position = Vector2(600, 310 + i * 60)
        h.size = Vector2(440, 1)
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(h)
        var v = ColorRect.new()
        v.color = Color(0.22, 0.18, 0.14)
        v.position = Vector2(640 + i * 80, 280)
        v.size = Vector2(1, 340)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(v)

func _build_hud() -> void:
    # Battery gauge.
    battery_label = Label.new()
    battery_label.text = "BATTERY"
    battery_label.position = Vector2(40, 40)
    battery_label.add_theme_color_override("font_color", COLOR_TEXT)
    battery_label.add_theme_font_size_override("font_size", 18)
    add_child(battery_label)
    var bar_bg = ColorRect.new()
    bar_bg.color = Color(0.06, 0.06, 0.06)
    bar_bg.position = Vector2(40, 66)
    bar_bg.size = Vector2(300, 20)
    add_child(bar_bg)
    battery_bar = ColorRect.new()
    battery_bar.color = COLOR_GLOW
    battery_bar.position = Vector2(40, 66)
    battery_bar.size = Vector2(300.0 * (main.battery / 100.0), 20)
    add_child(battery_bar)

    progress_label = Label.new()
    progress_label.text = "TRIANGULATED: %d / 3" % main.triangulated
    progress_label.position = Vector2(40, 100)
    progress_label.add_theme_color_override("font_color", COLOR_GLOW)
    progress_label.add_theme_font_size_override("font_size", 18)
    add_child(progress_label)

    status_label = Label.new()
    status_label.text = "Tune the dial to find signals."
    status_label.position = Vector2(40, 680)
    status_label.size = Vector2(1200, 30)
    status_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.55))
    status_label.add_theme_font_size_override("font_size", 16)
    add_child(status_label)

func _build_jam_overlay() -> void:
    jam_overlay = ColorRect.new()
    jam_overlay.color = Color(0.10, 0.30, 0.10, 0.0)
    jam_overlay.size = Vector2(1280, 720)
    jam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(jam_overlay)

func _on_dial_changed(v: float) -> void:
    dial_value = v
    freq_label.text = "FREQ: %.2f MHz" % (v * 108.0)
    _check_signal_lock()
    if jamming and absf(v - 0.5) < 0.05:
        _escape_jam()

func _check_signal_lock() -> void:
    locked_signal_idx = -1
    for i in range(SIGNALS_DATA.size()):
        var sig = SIGNALS_DATA[i]
        if absf(dial_value - sig.freq) < 0.03:
            locked_signal_idx = i
            break
    if locked_signal_idx >= 0:
        var sig = SIGNALS_DATA[locked_signal_idx]
        signal_label.text = "LOCKED: %s" % sig.name
        signal_label.add_theme_color_override("font_color", COLOR_GLOW)
        transcript_label.text = sig.text
    else:
        signal_label.text = "-- STATIC --"
        signal_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
        transcript_label.text = ""

func _on_place_pin() -> void:
    if locked_signal_idx < 0:
        status_label.text = "No signal locked. Tune the dial first."
        return
    if map_pins.has(locked_signal_idx):
        status_label.text = "Already pinned this signal."
        return
    map_pins.append(locked_signal_idx)
    main.signals_found += 1
    main.pins_placed += 1
    var sig = SIGNALS_DATA[locked_signal_idx]
    # Draw pin on map.
    var pin = ColorRect.new()
    pin.color = COLOR_PIN
    pin.position = Vector2(600 + sig.coords.x, 280 + sig.coords.y)
    pin.size = Vector2(12, 12)
    add_child(pin)
    pin_nodes.append(pin)
    status_label.text = "Pin placed: %s" % sig.name
    # Check triangulation.
    if map_pins.size() >= 3 and main.triangulated < 3:
        main.triangulated += 1
        progress_label.text = "TRIANGULATED: %d / 3" % main.triangulated
        main.battery = minf(main.battery + 10.0, 100.0)
        status_label.text = "TRIANGULATION COMPLETE. Battery restored."
    if main.triangulated >= 3:
        main._enter_ending()

func _escape_jam() -> void:
    jamming = false
    jam_overlay.color.a = 0.0
    status_label.text = "Escaped the jamming."

func _process(dt: float) -> void:
    elapsed += dt
    # Battery drain.
    main.battery -= battery_drain_rate * dt
    if main.battery <= 0:
        main.battery = 0
        main._enter_ending()
        return
    battery_bar.size.x = 300.0 * (main.battery / 100.0)
    if main.battery < 25:
        battery_bar.color = COLOR_WARN
    # Jamming events.
    if not jamming:
        next_jam_time -= dt
        if next_jam_time <= 0:
            jamming = true
            jam_timer = 0.0
            jam_escape_window = 4.0
            next_jam_time = 6.0 + rng.randf() * 4.0
            status_label.text = "JAMMING! Retune to 0.50 to escape!"
    else:
        jam_timer += dt
        var pulse = 0.3 + 0.2 * sin(jam_timer * 8.0)
        jam_overlay.color = Color(0.10, 0.30, 0.10, pulse)
        jam_escape_window -= dt
        if jam_escape_window <= 0:
            jamming = false
            jam_overlay.color.a = 0.0
            main.battery -= 15.0
            status_label.text = "Jam escaped you. Battery drained."

func _make_button(text: String, pos: Vector2) -> Button:
    var b = Button.new()
    b.text = text
    b.position = pos
    b.size = Vector2(180, 50)
    var sb = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL
    sb.border_color = COLOR_GLOW
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", COLOR_TEXT)
    b.add_theme_font_size_override("font_size", 20)
    return b
