extends Node2D

var main: Node = null

const COLOR_BG = Color(0.06, 0.05, 0.04)
const COLOR_WALL = Color(0.14, 0.12, 0.10)
const COLOR_GOLD = Color(0.75, 0.60, 0.30)
const COLOR_DARK_GOLD = Color(0.45, 0.35, 0.18)
const COLOR_PANEL = Color(0.10, 0.08, 0.06)
const COLOR_TEXT = Color(0.90, 0.85, 0.70)
const COLOR_DOOR = Color(0.22, 0.18, 0.14)
const COLOR_WARN = Color(0.80, 0.25, 0.20)

const PASSENGER_NAMES = ["Mr. Grey", "The Child", "Ms. Hollow", "The Bellhop", "Nobody"]
const PASSENGER_COLORS = [
    Color(0.50, 0.50, 0.55),
    Color(0.70, 0.55, 0.45),
    Color(0.30, 0.30, 0.35),
    Color(0.60, 0.45, 0.30),
    Color(0.15, 0.15, 0.18),
]

var floor_indicator: Label = null
var passenger_label: Label = null
var request_label: Label = null
var status_label: Label = null
var corruption_label: Label = null
var door_left: ColorRect = null
var door_right: ColorRect = null
var floor_buttons: Array = []

var current_passenger_idx: int = 0
var requested_floor: int = 3
var moving: bool = false
var move_timer: float = 0.0
var target_floor: int = 1
var doors_open: bool = true
var door_anim_timer: float = 0.0
var door_opening: bool = false
var door_closing: bool = false
var malfunction_active: bool = false
var rng: RandomNumberGenerator = null

func _ready() -> void:
    rng = RandomNumberGenerator.new()
    rng.seed = 42 + main.passengers_served * 7
    _build_interior()
    _build_panel()
    _build_hud()
    _spawn_passenger()
    set_process(true)

func _build_interior() -> void:
    var bg = ColorRect.new()
    bg.color = COLOR_BG
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Elevator walls.
    var left_wall = ColorRect.new()
    left_wall.color = COLOR_WALL
    left_wall.position = Vector2(100, 80)
    left_wall.size = Vector2(40, 520)
    add_child(left_wall)
    var right_wall = ColorRect.new()
    right_wall.color = COLOR_WALL
    right_wall.position = Vector2(740, 80)
    right_wall.size = Vector2(40, 520)
    add_child(right_wall)
    var ceiling = ColorRect.new()
    ceiling.color = Color(0.12, 0.10, 0.08)
    ceiling.position = Vector2(100, 80)
    ceiling.size = Vector2(680, 30)
    add_child(ceiling)
    var floor_r = ColorRect.new()
    floor_r.color = Color(0.08, 0.06, 0.05)
    floor_r.position = Vector2(100, 570)
    floor_r.size = Vector2(680, 30)
    add_child(floor_r)

    # Doors.
    door_left = ColorRect.new()
    door_left.color = COLOR_DOOR
    door_left.position = Vector2(240, 110)
    door_left.size = Vector2(0, 460)
    add_child(door_left)
    door_right = ColorRect.new()
    door_right.color = COLOR_DOOR
    door_right.position = Vector2(640, 110)
    door_right.size = Vector2(0, 460)
    add_child(door_right)

    # Shaft view (visible when doors open).
    var shaft = ColorRect.new()
    shaft.color = Color(0.02, 0.02, 0.03)
    shaft.position = Vector2(240, 110)
    shaft.size = Vector2(400, 460)
    shaft.z_index = -1
    add_child(shaft)

func _build_panel() -> void:
    # Floor selector panel on the right side.
    var panel_bg = ColorRect.new()
    panel_bg.color = COLOR_PANEL
    panel_bg.position = Vector2(840, 80)
    panel_bg.size = Vector2(380, 520)
    add_child(panel_bg)
    var panel_border = ColorRect.new()
    panel_border.color = COLOR_DARK_GOLD
    panel_border.position = Vector2(838, 78)
    panel_border.size = Vector2(384, 524)
    panel_border.z_index = -1
    add_child(panel_border)

    var panel_title = Label.new()
    panel_title.text = "SELECT FLOOR"
    panel_title.position = Vector2(840, 90)
    panel_title.size = Vector2(380, 30)
    panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel_title.add_theme_color_override("font_color", COLOR_GOLD)
    panel_title.add_theme_font_size_override("font_size", 20)
    add_child(panel_title)

    floor_buttons.clear()
    for i in range(12):
        var row = i / 3
        var col = i % 3
        var x = 870 + col * 120
        var y = 130 + row * 100
        var btn = Button.new()
        btn.text = str(i + 1)
        btn.position = Vector2(x, y)
        btn.size = Vector2(90, 70)
        var sb = StyleBoxFlat.new()
        sb.bg_color = COLOR_DARK_GOLD
        sb.border_color = COLOR_GOLD
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(4)
        btn.add_theme_stylebox_override("normal", sb)
        btn.add_theme_stylebox_override("hover", sb)
        btn.add_theme_stylebox_override("pressed", sb)
        btn.add_theme_color_override("font_color", COLOR_TEXT)
        btn.add_theme_font_size_override("font_size", 22)
        var floor_num = i + 1
        btn.pressed.connect(func(): _on_floor_selected(floor_num))
        add_child(btn)
        floor_buttons.append(btn)

func _build_hud() -> void:
    floor_indicator = Label.new()
    floor_indicator.text = "FLOOR: %d" % main.current_floor
    floor_indicator.position = Vector2(140, 40)
    floor_indicator.size = Vector2(200, 40)
    floor_indicator.add_theme_color_override("font_color", COLOR_GOLD)
    floor_indicator.add_theme_font_size_override("font_size", 28)
    add_child(floor_indicator)

    corruption_label = Label.new()
    corruption_label.text = "CURSE: %d/6" % main.corruption
    corruption_label.position = Vector2(600, 40)
    corruption_label.size = Vector2(200, 40)
    corruption_label.add_theme_color_override("font_color", COLOR_WARN)
    corruption_label.add_theme_font_size_override("font_size", 22)
    add_child(corruption_label)

    passenger_label = Label.new()
    passenger_label.position = Vector2(140, 620)
    passenger_label.size = Vector2(400, 30)
    passenger_label.add_theme_color_override("font_color", COLOR_TEXT)
    passenger_label.add_theme_font_size_override("font_size", 20)
    add_child(passenger_label)

    request_label = Label.new()
    request_label.position = Vector2(140, 650)
    request_label.size = Vector2(600, 30)
    request_label.add_theme_color_override("font_color", COLOR_GOLD)
    request_label.add_theme_font_size_override("font_size", 20)
    add_child(request_label)

    status_label = Label.new()
    status_label.position = Vector2(140, 680)
    status_label.size = Vector2(600, 30)
    status_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
    status_label.add_theme_font_size_override("font_size", 18)
    add_child(status_label)

func _spawn_passenger() -> void:
    current_passenger_idx = rng.randi_range(0, PASSENGER_NAMES.size() - 1)
    requested_floor = rng.randi_range(1, 12)
    while requested_floor == main.current_floor:
        requested_floor = rng.randi_range(1, 12)
    if main.corruption >= 4:
        requested_floor = 13
    passenger_label.text = "Passenger: %s" % PASSENGER_NAMES[current_passenger_idx]
    request_label.text = "\"Take me to floor %d.\"" % requested_floor
    status_label.text = "Select a floor on the panel."
    # Draw passenger silhouette in the shaft area.
    var sil = ColorRect.new()
    sil.color = PASSENGER_COLORS[current_passenger_idx]
    sil.position = Vector2(380, 320)
    sil.size = Vector2(60, 140)
    sil.name = "PassengerSil"
    add_child(sil)
    var head = ColorRect.new()
    head.color = PASSENGER_COLORS[current_passenger_idx].lightened(0.15)
    head.position = Vector2(390, 280)
    head.size = Vector2(40, 40)
    head.name = "PassengerHead"
    add_child(head)

func _on_floor_selected(floor_num: int) -> void:
    if moving or door_closing or door_opening:
        return
    target_floor = floor_num
    _close_doors()

func _close_doors() -> void:
    door_closing = true
    door_anim_timer = 0.0
    status_label.text = "Doors closing..."

func _open_doors() -> void:
    door_opening = true
    door_anim_timer = 0.0

func _process(dt: float) -> void:
    if door_closing:
        door_anim_timer += dt
        var k = clampf(door_anim_timer / 0.6, 0.0, 1.0)
        door_left.size.x = 200.0 * k
        door_right.size.x = 200.0 * k
        door_right.position.x = 640.0 - 200.0 * k
        if k >= 1.0:
            door_closing = false
            doors_open = false
            moving = true
            move_timer = 0.0
            status_label.text = "Moving to floor %d..." % target_floor
    elif moving:
        move_timer += dt
        if move_timer >= 1.2:
            moving = false
            main.current_floor = target_floor
            floor_indicator.text = "FLOOR: %d" % main.current_floor
            # Check malfunction.
            if main.corruption >= 2 and rng.randf() < 0.3:
                malfunction_active = true
                var wrong = rng.randi_range(1, 12)
                main.current_floor = wrong
                floor_indicator.text = "FLOOR: %d ?!" % wrong
                status_label.text = "MALFUNCTION -- wrong floor!"
            _open_doors()
    elif door_opening:
        door_anim_timer += dt
        var k = clampf(door_anim_timer / 0.6, 0.0, 1.0)
        door_left.size.x = 200.0 * (1.0 - k)
        door_right.size.x = 200.0 * (1.0 - k)
        door_right.position.x = 640.0 - 200.0 * (1.0 - k)
        if k >= 1.0:
            door_opening = false
            doors_open = true
            _on_arrived()

func _on_arrived() -> void:
    # Remove old passenger.
    var sil = get_node_or_null("PassengerSil")
    if sil:
        sil.queue_free()
    var head = get_node_or_null("PassengerHead")
    if head:
        head.queue_free()
    main.passengers_served += 1
    # Consequence: wrong floor adds corruption.
    if target_floor != requested_floor and requested_floor != 13:
        main.add_corruption(1)
        corruption_label.text = "CURSE: %d/6" % main.corruption
        status_label.text = "The passenger stares. Corruption rises."
    elif requested_floor == 13:
        main.add_corruption(2)
        corruption_label.text = "CURSE: %d/6" % main.corruption
        status_label.text = "You should not have gone there."
    else:
        status_label.text = "Delivered safely."
    if main.corruption >= 6:
        return
    # After a beat, go to floor view or spawn next passenger.
    if main.passengers_served >= 5:
        main.current_floor = 13
        main._enter_ending()
    else:
        main._enter_floor_view()
