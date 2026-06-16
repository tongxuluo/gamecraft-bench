#!/bin/bash
# Reference solution for gamecraft-bench/roguelike-rulescape.
#
# Generates a compact rules-horror roguelike:
#   - Title -> character select -> random anomaly site -> exploration -> result.
#   - Three survivors with distinct skills.
#   - Three anomaly sites: hospital, school, subway.
#   - WASD/arrow movement through a top-down room-and-corridor playfield.
#   - Normal in-game timetable, timed rule reveals, anomaly encounters,
#     win/lose states.
#   - Demo traces cover site variety, skill use, rule reveal, anomaly handling,
#     victory, and failure.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Rulescape"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT'
extends Node2D

const VIEW := Vector2(1280, 720)
const AREA_POS := {
    "Entrance": Vector2(260, 360),
    "Station": Vector2(500, 260),
    "Ward": Vector2(500, 460),
    "Archive": Vector2(760, 260),
    "Exit": Vector2(980, 360),
    "Tunnel": Vector2(760, 500),
}

const AREA_RECTS := {
    "Entrance": Rect2(330, 300, 150, 120),
    "Station": Rect2(430, 200, 150, 120),
    "Ward": Rect2(430, 400, 150, 120),
    "Archive": Rect2(690, 195, 150, 130),
    "Exit": Rect2(900, 300, 120, 120),
    "Tunnel": Rect2(690, 420, 150, 110),
}

var scenario := ""
var mode := "title"
var site_id := "hospital"
var hero_id := "reporter"
var selected_area := "Entrance"
var time_min := 0
var clock_accum := 0.0
var hp := 3
var sanity := 3
var skill_ready := true
var searched := {}
var inventory: Array[String] = []
var rules: Array[String] = []
var message := ""
var anomaly_active := false
var result_title := ""
var result_body := ""

var sites := {
    "hospital": {
        "title": "St. Orison Hospital",
        "palette": Color(0.08, 0.12, 0.13),
        "accent": Color(0.58, 0.08, 0.10),
        "anomaly": "Red Nurse",
        "goal": "Find the blue keycard and reach the elevator before the ward resets.",
        "rule1": "Rule 1: If the ward lights turn red, do not search the Ward.",
        "rule2": "Rule 2: The nurse smiles only before she attacks.",
        "item": "Blue Keycard",
        "escape": "The elevator accepts the blue keycard.",
        "floor": Color(0.13, 0.17, 0.17),
        "wall": Color(0.055, 0.075, 0.075),
        "props": ["gurneys", "IV bags", "morgue drawers", "blood chart"],
        "event": "A wet intercom coughs your patient number."
    },
    "school": {
        "title": "No. 4 Night School",
        "palette": Color(0.10, 0.09, 0.14),
        "accent": Color(0.44, 0.34, 0.08),
        "anomaly": "Headless Monitor",
        "goal": "Find the attendance book and leave through the locked gate.",
        "rule1": "Rule 1: When the bell rings, stand under a lit sign.",
        "rule2": "Rule 2: Never answer roll call after 00:40.",
        "item": "Attendance Book",
        "escape": "The gate opens after the missing name is crossed out.",
        "floor": Color(0.14, 0.12, 0.16),
        "wall": Color(0.07, 0.06, 0.09),
        "props": ["desks", "chalk circles", "lockers", "class bell"],
        "event": "Chalk dust forms a name that is not yours."
    },
    "subway": {
        "title": "Line 404",
        "palette": Color(0.06, 0.08, 0.11),
        "accent": Color(0.05, 0.42, 0.52),
        "anomaly": "Faceless Passenger",
        "goal": "Restore the breaker and leave through the emergency gate.",
        "rule1": "Rule 1: Do not board train 404 when the announcement stutters.",
        "rule2": "Rule 2: Passengers without faces count your footsteps.",
        "item": "Breaker Fuse",
        "escape": "The emergency gate unlocks after power returns.",
        "floor": Color(0.08, 0.11, 0.13),
        "wall": Color(0.035, 0.045, 0.055),
        "props": ["ticket gates", "map boards", "dark rails", "sparking fusebox"],
        "event": "The platform announcement repeats one syllable too long."
    }
}

var heroes := {
    "reporter": {
        "name": "Mara Vale - Reporter",
        "skill": "Expose Falsehood",
        "desc": "Reveal a hidden clue and reduce sanity loss once."
    },
    "orderly": {
        "name": "Jon Ives - Orderly",
        "skill": "Hold Breath",
        "desc": "Survive one anomaly strike without injury."
    },
    "medium": {
        "name": "Edda Rune - Medium",
        "skill": "Bind Omen",
        "desc": "Freeze the anomaly and open a safer branch once."
    }
}

func _ready() -> void:
    _parse_args()
    if scenario != "":
        _load_scenario(scenario)
    queue_redraw()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _load_scenario(id: String) -> void:
    if id == "school_bell":
        hero_id = "medium"; site_id = "school"; mode = "explore"; time_min = 35
        selected_area = "Station"; _init_run(false); message = "The bell is about to ring."
    elif id == "subway_encounter":
        hero_id = "orderly"; site_id = "subway"; mode = "explore"; time_min = 45
        selected_area = "Tunnel"; _init_run(false); _trigger_anomaly()
    elif id == "near_escape":
        hero_id = "reporter"; site_id = "hospital"; mode = "explore"; time_min = 50
        selected_area = "Exit"; _init_run(false); inventory.append(sites[site_id]["item"]); message = sites[site_id]["escape"]
    elif id == "rule_violation":
        hero_id = "orderly"; site_id = "hospital"; mode = "explore"; time_min = 40
        selected_area = "Ward"; _init_run(false); anomaly_active = true; message = "The ward lights are red."
    else:
        hero_id = "reporter"; site_id = "hospital"; mode = "explore"; time_min = 0
        selected_area = "Entrance"; _init_run(false)

func _init_run(random_site: bool) -> void:
    if random_site:
        var order := ["hospital", "school", "subway"]
        site_id = order[int(Time.get_ticks_msec() / 1000) % order.size()]
    hp = 3
    sanity = 3
    skill_ready = true
    searched.clear()
    inventory.clear()
    rules = [sites[site_id]["rule1"]]
    message = sites[site_id]["goal"]
    anomaly_active = false
    if time_min >= 30 and not rules.has(sites[site_id]["rule2"]):
        rules.append(sites[site_id]["rule2"])

func _draw() -> void:
    var site = sites[site_id]
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.025, 0.025, 0.03))
    _draw_blood_sky(site)
    if mode == "title":
        _draw_title()
    elif mode == "select":
        _draw_character_select()
    elif mode == "explore":
        _draw_explore()
    elif mode == "result":
        _draw_result()

func _draw_blood_sky(site: Dictionary) -> void:
    draw_rect(Rect2(0, 0, 1280, 720), site["palette"])
    for i in range(24):
        var x := float((i * 97) % 1280)
        var y := float((i * 53) % 720)
        draw_circle(Vector2(x, y), 2.0 + float(i % 3), Color(0.7, 0.7, 0.62, 0.16))
    draw_circle(Vector2(1080, 120), 80, Color(site["accent"].r, site["accent"].g, site["accent"].b, 0.25))

func _draw_panel(rect: Rect2, color := Color(0.06, 0.065, 0.075, 0.92)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.45, 0.38, 0.30, 0.95), false, 2.0)

func _draw_title() -> void:
    _draw_panel(Rect2(330, 170, 620, 330))
    _draw_text("RULESCAPE", Vector2(410, 260), 64, Color(0.92, 0.78, 0.55))
    _draw_text("Read the rules. Avoid the anomalies. Reach the escape moment.", Vector2(375, 320), 22, Color(0.78, 0.74, 0.68))
    _draw_button(Rect2(520, 390, 240, 70), "START RUN")
    _draw_text("Blood on the notice board dries into instructions.", Vector2(385, 590), 18, Color(0.65, 0.15, 0.15))

func _draw_character_select() -> void:
    _draw_text("Choose a survivor", Vector2(430, 90), 42, Color(0.9, 0.82, 0.70))
    var ids := ["reporter", "orderly", "medium"]
    for i in range(ids.size()):
        var id: String = ids[i]
        var r: Rect2 = Rect2(110 + i * 390, 180, 320, 330)
        _draw_panel(r)
        draw_circle(r.position + Vector2(160, 80), 48, Color(0.16 + i * 0.08, 0.16, 0.18))
        draw_circle(r.position + Vector2(160, 60), 20, Color(0.78, 0.72, 0.63))
        draw_rect(Rect2(r.position + Vector2(128, 84), Vector2(64, 92)), Color(0.18, 0.16, 0.18))
        _draw_text(heroes[id]["name"], r.position + Vector2(24, 160), 23, Color(0.95, 0.86, 0.68))
        _draw_text(heroes[id]["skill"], r.position + Vector2(24, 205), 20, Color(0.75, 0.14, 0.15))
        _draw_text(heroes[id]["desc"], r.position + Vector2(24, 245), 16, Color(0.78, 0.78, 0.72))
        _draw_button(Rect2(r.position + Vector2(70, 285), Vector2(180, 42)), "SELECT")

func _draw_explore() -> void:
    var site = sites[site_id]
    _draw_text(site["title"], Vector2(40, 42), 34, Color(0.94, 0.82, 0.62))
    _draw_text("Clock %02d:%02d   HP %d   Sanity %d" % [23 + int(time_min / 60), time_min % 60, hp, sanity], Vector2(40, 82), 23, Color(0.88, 0.88, 0.82))
    _draw_text("Survivor: %s  Skill: %s %s" % [heroes[hero_id]["name"], heroes[hero_id]["skill"], "(ready)" if skill_ready else "(spent)"], Vector2(40, 112), 18, Color(0.70, 0.72, 0.78))

    _draw_panel(Rect2(30, 145, 250, 475))
    _draw_text("RULES", Vector2(55, 185), 26, Color(0.90, 0.76, 0.55))
    for i in range(rules.size()):
        _draw_wrapped(rules[i], Rect2(55, 220 + i * 88, 195, 76), 16, Color(0.82, 0.80, 0.72))
    _draw_text("Inventory: " + (", ".join(inventory) if inventory.size() else "empty"), Vector2(55, 560), 16, Color(0.72, 0.72, 0.68))

    _draw_site_map(site)
    if anomaly_active:
        var ap: Vector2 = AREA_POS[selected_area] + Vector2(80, -80)
        draw_circle(ap, 42, Color(0.55, 0.02, 0.05))
        draw_circle(ap + Vector2(-12, -8), 5, Color(1, 0.9, 0.8))
        draw_circle(ap + Vector2(12, -8), 5, Color(1, 0.9, 0.8))
        _draw_text(site["anomaly"], ap + Vector2(-60, 65), 18, Color(0.95, 0.25, 0.24))

    _draw_panel(Rect2(995, 145, 255, 475))
    _draw_text("ACTIONS", Vector2(1030, 185), 26, Color(0.90, 0.76, 0.55))
    _draw_button(Rect2(1030, 230, 180, 48), "SEARCH")
    _draw_button(Rect2(1030, 295, 180, 48), "HIDE")
    _draw_button(Rect2(1030, 360, 180, 48), "SKILL")
    _draw_button(Rect2(1030, 425, 180, 48), "ESCAPE")
    _draw_wrapped(message, Rect2(1022, 500, 210, 94), 16, Color(0.82, 0.78, 0.68))

    if hp < 3 or sanity < 3:
        draw_rect(Rect2(0, 0, 1280, 720), Color(0.45, 0.0, 0.0, 0.08))

func _draw_site_map(site: Dictionary) -> void:
    _draw_panel(Rect2(300, 145, 670, 475), site["wall"])
    var links := [["Entrance","Station"],["Entrance","Ward"],["Station","Archive"],["Ward","Tunnel"],["Archive","Exit"],["Tunnel","Exit"]]
    for link in links:
        draw_line(AREA_POS[link[0]], AREA_POS[link[1]], Color(0.18, 0.16, 0.14), 52.0)
        draw_line(AREA_POS[link[0]], AREA_POS[link[1]], site["floor"], 38.0)
    for a in AREA_RECTS.keys():
        var r: Rect2 = AREA_RECTS[a]
        var active: bool = a == selected_area
        draw_rect(r.grow(8), Color(0.025, 0.025, 0.03))
        draw_rect(r, site["floor"])
        draw_rect(r, Color(site["accent"].r, site["accent"].g, site["accent"].b, 0.75 if active else 0.35), false, 3.0)
        _draw_room_props(site, a, r)
        _draw_text(a, r.position + Vector2(10, 24), 16, Color(0.88, 0.82, 0.70))
    _draw_avatar(AREA_POS[selected_area])

func _draw_room_props(site: Dictionary, area: String, r: Rect2) -> void:
    var prop_names: Array = site["props"]
    for i in range(3):
        var px := r.position.x + 24.0 + float(i) * 38.0
        var py := r.position.y + 56.0 + float((i + area.length()) % 2) * 28.0
        draw_rect(Rect2(px, py, 30, 14), Color(0.22, 0.20, 0.18))
        draw_rect(Rect2(px + 4, py - 3, 22, 4), site["accent"])
    if area in ["Ward", "Archive", "Tunnel"]:
        draw_circle(r.position + Vector2(r.size.x - 26, r.size.y - 24), 10, Color(0.65, 0.04, 0.04))
        _draw_text(prop_names[min(3, prop_names.size() - 1)], r.position + Vector2(10, r.size.y - 14), 13, Color(0.70, 0.65, 0.58))

func _draw_avatar(pos: Vector2) -> void:
    draw_circle(pos + Vector2(0, -18), 13, Color(0.76, 0.70, 0.62))
    draw_rect(Rect2(pos.x - 11, pos.y - 4, 22, 32), Color(0.20, 0.20, 0.24))
    draw_line(pos + Vector2(-18, 4), pos + Vector2(18, 4), Color(0.76, 0.70, 0.62), 4.0)
    draw_line(pos + Vector2(-8, 28), pos + Vector2(-15, 44), Color(0.76, 0.70, 0.62), 4.0)
    draw_line(pos + Vector2(8, 28), pos + Vector2(15, 44), Color(0.76, 0.70, 0.62), 4.0)

func _draw_result() -> void:
    _draw_panel(Rect2(310, 170, 660, 360))
    _draw_text(result_title, Vector2(400, 260), 52, Color(0.94, 0.78, 0.55))
    _draw_wrapped(result_body, Rect2(390, 320, 500, 90), 22, Color(0.82, 0.80, 0.72))
    _draw_button(Rect2(440, 440, 170, 58), "RETRY")
    _draw_button(Rect2(670, 440, 170, 58), "TITLE")

func _draw_button(rect: Rect2, text: String) -> void:
    draw_rect(rect, Color(0.11, 0.11, 0.13))
    draw_rect(rect, Color(0.72, 0.62, 0.46), false, 2.0)
    _draw_text(text, rect.position + Vector2(18, rect.size.y * 0.62), 22, Color(0.94, 0.86, 0.66))

func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_wrapped(text: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if mode == "explore":
            var dir := ""
            if event.keycode in [KEY_W, KEY_UP]: dir = "up"
            elif event.keycode in [KEY_S, KEY_DOWN]: dir = "down"
            elif event.keycode in [KEY_A, KEY_LEFT]: dir = "left"
            elif event.keycode in [KEY_D, KEY_RIGHT]: dir = "right"
            elif event.keycode == KEY_SPACE: _search()
            elif event.keycode == KEY_1: _hide()
            elif event.keycode == KEY_2: _use_skill()
            elif event.keycode == KEY_ENTER: _try_escape()
            if dir != "":
                _move(dir)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(520, 390, 240, 70).has_point(p):
            mode = "select"; queue_redraw()
    elif mode == "select":
        var ids := ["reporter", "orderly", "medium"]
        for i in range(ids.size()):
            if Rect2(180 + i * 390, 465, 180, 42).has_point(p):
                hero_id = ids[i]; time_min = 0; selected_area = "Entrance"; mode = "explore"; _init_run(true); queue_redraw()
    elif mode == "explore":
        if Rect2(1030, 230, 180, 48).has_point(p): _search()
        elif Rect2(1030, 295, 180, 48).has_point(p): _hide()
        elif Rect2(1030, 360, 180, 48).has_point(p): _use_skill()
        elif Rect2(1030, 425, 180, 48).has_point(p): _try_escape()
    elif mode == "result":
        if Rect2(440, 440, 170, 58).has_point(p):
            mode = "select"; queue_redraw()
        elif Rect2(670, 440, 170, 58).has_point(p):
            mode = "title"; queue_redraw()

func _neighbors(area: String) -> Dictionary:
    return {
        "Entrance": {"right":"Station", "down":"Ward"},
        "Station": {"left":"Entrance", "right":"Archive", "down":"Ward"},
        "Ward": {"up":"Station", "right":"Tunnel", "left":"Entrance"},
        "Archive": {"left":"Station", "down":"Exit"},
        "Tunnel": {"left":"Ward", "right":"Exit", "up":"Archive"},
        "Exit": {"left":"Archive", "down":"Tunnel"},
    }[area]

func _move(dir: String) -> void:
    var n := _neighbors(selected_area)
    if n.has(dir):
        selected_area = n[dir]
        message = "Entered %s. The walls seem to listen." % selected_area
    queue_redraw()

func _search() -> void:
    if anomaly_active and selected_area == "Ward":
        _anomaly_harm()
        queue_redraw()
        return
    var key := site_id + ":" + selected_area
    if not searched.has(key):
        searched[key] = true
        if selected_area in ["Archive", "Ward", "Tunnel"]:
            inventory.append(sites[site_id]["item"])
            message = "Found %s. %s" % [sites[site_id]["item"], sites[site_id]["escape"]]
        else:
            message = "Found a note: %s" % sites[site_id]["rule1"]
    else:
        message = "Only old blood and static remain."
    queue_redraw()

func _hide() -> void:
    if anomaly_active:
        anomaly_active = false
        message = "You hide and count seven breaths. The anomaly passes."
    else:
        message = "You waste time hiding from empty air."
    queue_redraw()

func _use_skill() -> void:
    if not skill_ready:
        message = "The skill is spent."
        queue_redraw()
        return
    skill_ready = false
    anomaly_active = false
    if hero_id == "reporter":
        sanity = min(3, sanity + 1)
        message = "Expose Falsehood: a hidden clue confirms the second rule."
    elif hero_id == "orderly":
        hp = min(3, hp + 1)
        message = "Hold Breath: the anomaly misses your pulse."
    else:
        message = "Bind Omen: the anomaly freezes and the safe path opens."
    if not rules.has(sites[site_id]["rule2"]):
        rules.append(sites[site_id]["rule2"])
    queue_redraw()

func _try_escape() -> void:
    if selected_area == "Exit" and inventory.has(sites[site_id]["item"]):
        _finish(true, "You understood the rule too late to feel safe, but early enough to escape.")
    else:
        message = "The exit refuses you. Find the site's required item."
        queue_redraw()

func _advance_time(delta_min: int) -> void:
    time_min += delta_min
    if time_min >= 30 and not rules.has(sites[site_id]["rule2"]):
        rules.append(sites[site_id]["rule2"])
        message = "A new rule bleeds through the wall: " + sites[site_id]["rule2"]
    if time_min >= 45 and not anomaly_active:
        _trigger_anomaly()
    if time_min >= 75:
        _finish(false, "The clock reaches the escape moment without you. The site keeps your name.")

func _trigger_anomaly() -> void:
    anomaly_active = true
    message = "%s appears. The rule suddenly makes sense." % sites[site_id]["anomaly"]

func _anomaly_harm() -> void:
    if anomaly_active:
        hp -= 1
        sanity -= 1
        message = "Blood spots the floor. The anomaly punishes hesitation."
        if hp <= 0 or sanity <= 0:
            _finish(false, "You broke under the rule. The anomaly writes your ending.")

func _finish(win: bool, body: String) -> void:
    mode = "result"
    result_title = "ESCAPED" if win else "DISAPPEARED"
    result_body = body
    anomaly_active = false
    queue_redraw()

func _process(delta: float) -> void:
    if mode == "explore":
        clock_accum += delta
        if clock_accum >= 1.5:
            clock_accum = 0.0
            _advance_time(5)
            queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_select.json" <<'EOF'
{
  "duration_frames": 360,
  "events": [
    {"frame": 30, "type": "mouse_click", "button": "left", "x": 640, "y": 425},
    {"frame": 90, "type": "mouse_click", "button": "left", "x": 255, "y": 486},
    {"frame": 160, "type": "key_press", "keycode": "D"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 330, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_school_rules.json" <<'EOF'
{
  "scenario": "school_bell",
  "duration_frames": 420,
  "events": [
    {"frame": 40, "type": "key_press", "keycode": "D"},
    {"frame": 100, "type": "key_press", "keycode": "SPACE"},
    {"frame": 170, "type": "key_press", "keycode": "2"},
    {"frame": 260, "type": "key_press", "keycode": "S"},
    {"frame": 390, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_subway_encounter.json" <<'EOF'
{
  "scenario": "subway_encounter",
  "duration_frames": 360,
  "events": [
    {"frame": 50, "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "key_press", "keycode": "D"},
    {"frame": 180, "type": "key_press", "keycode": "SPACE"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_near_escape.json" <<'EOF'
{
  "scenario": "near_escape",
  "duration_frames": 260,
  "events": [
    {"frame": 60, "type": "key_press", "keycode": "ENTER"},
    {"frame": 220, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_rule_violation.json" <<'EOF'
{
  "scenario": "rule_violation",
  "duration_frames": 420,
  "events": [
    {"frame": 40, "type": "key_press", "keycode": "SPACE"},
    {"frame": 120, "type": "key_press", "keycode": "SPACE"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

echo "rulescape oracle generated at $GAME"
