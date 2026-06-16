#!/bin/bash
# Reference solution for gamecraft-bench/shooter-bullet-cathedral.
#
# A compact top-down bullet-hell roguelike oracle:
#   - Title -> run -> rooms with enemies firing radial bullet spreads -> boss
#     -> result. WASD move, mouse-aim + click to fire, SPACE dodge-roll (i-frames).
#   - Player HP (hearts) depletes on bullet hits; 0 HP = game over.
#   - Clearing a room's enemies opens the next room; gun pickup swaps pattern.
#   - Several enemy types + a boss with multiple bullet phases.
#   - Run-end result screen (victory / death) with rooms-cleared stats.
#   - Scenarios jump to combat / boss / death for deterministic demos.
#
# Oracle for the verifier: drawn from primitives, so art items (A*) stay low
# while mechanic/content items pass. Logic runs in _physics_process (fixed step)
# for deterministic replay.
#
# NOTE (GDScript warnings-as-errors): min()/max()/Dictionary subscripts return
# Variant; each such value is given an explicit type to avoid parse errors.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="BulletCathedral"
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
const ARENA := Rect2(180, 120, 920, 480)
const PR := 14.0
const ROLL_TIME := 0.35
const ROLL_IFRAME := 0.25
const MAX_HP := 6

const GUNS := [
    {"name": "Pistol", "pat": "single", "cd": 0.18, "spd": 540.0, "dmg": 1},
    {"name": "Shotgun", "pat": "spread", "cd": 0.5, "spd": 480.0, "dmg": 1},
    {"name": "Railgun", "pat": "pierce", "cd": 0.6, "spd": 900.0, "dmg": 3},
]

var scenario := ""
var mode := "title"
var room := 1
var rooms_cleared := 0
var gun := 0
var hp := MAX_HP
var aim := Vector2(640, 360)
var ppos := Vector2(640, 360)
var roll_t := 0.0
var fire_cd := 0.0
var move := {"up": false, "down": false, "left": false, "right": false}
var pbul: Array = []
var ebul: Array = []
var enemies: Array = []
var won := false
var anim := 0.0
var msg := ""
var rng := RandomNumberGenerator.new()
var efire := 0.0

func _ready() -> void:
    rng.seed = 31337
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
    if id == "title_flow":
        mode = "title"
    elif id == "battle" or id == "combat":
        _start_run(); _spawn_room(1)
    elif id == "boss":
        _start_run(); room = 3; _spawn_boss()
    elif id == "near_victory":
        _start_run(); room = 3; _spawn_boss(); enemies[0]["hp"] = 4
    elif id == "death":
        _start_run(); hp = 1; _spawn_room(1)
    else:
        _start_run(); _spawn_room(1)

func _start_run() -> void:
    mode = "play"
    room = 1
    rooms_cleared = 0
    gun = 0
    hp = MAX_HP
    ppos = Vector2(640, 360)
    roll_t = 0.0
    fire_cd = 0.0
    pbul = []
    ebul = []
    enemies = []
    won = false
    msg = "Clear the room. WASD move, click fire, SPACE roll."

func _spawn_room(n: int) -> void:
    enemies = []
    ebul = []
    var count := 2 + n
    var kinds := ["radial", "aimed", "spiral"]
    for i in range(count):
        var ex := ARENA.position.x + 120.0 + float(i) * 180.0
        var ey := ARENA.position.y + 80.0 + float(i % 2) * 200.0
        enemies.append({"pos": Vector2(ex, ey), "hp": 4, "kind": kinds[i % 3],
                        "t": float(i) * 0.3, "boss": false, "phase": 0})

func _spawn_boss() -> void:
    enemies = []
    ebul = []
    enemies.append({"pos": Vector2(640, 220), "hp": 30, "kind": "boss",
                    "t": 0.0, "boss": true, "phase": 0})
    msg = "BOSS - survive the patterns and fire back."

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "play":
        return
    fire_cd = max(0.0, fire_cd - delta)
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    var spd := 230.0
    if roll_t > 0.0:
        roll_t = max(0.0, roll_t - delta)
        spd = 460.0
    ppos += dir.normalized() * spd * delta
    ppos.x = clampf(ppos.x, ARENA.position.x + PR, ARENA.position.x + ARENA.size.x - PR)
    ppos.y = clampf(ppos.y, ARENA.position.y + PR, ARENA.position.y + ARENA.size.y - PR)

    var pk: Array = []
    for b in pbul:
        b["pos"] += b["vel"] * delta
        if ARENA.grow(40).has_point(b["pos"]):
            pk.append(b)
    pbul = pk

    for e in enemies:
        e["t"] += delta
        if not e["boss"]:
            e["pos"] += (ppos - e["pos"]).normalized() * 26.0 * delta
        else:
            e["phase"] = clampi(int((30 - int(e["hp"])) / 10), 0, 2)
    efire += delta
    if efire >= 0.6:
        efire = 0.0
        for e in enemies:
            _enemy_fire(e)

    var ek: Array = []
    for b in ebul:
        b["pos"] += b["vel"] * delta
        if ARENA.grow(40).has_point(b["pos"]):
            ek.append(b)
    ebul = ek

    _collisions()
    if hp <= 0:
        _finish(false)
    elif enemies.size() == 0:
        _on_room_clear()
    queue_redraw()

func _enemy_fire(e: Dictionary) -> void:
    var origin: Vector2 = e["pos"]
    var k: String = str(e["kind"])
    if e["boss"]:
        var n := 12 + int(e["phase"]) * 6
        for i in range(n):
            var a: float = TAU * float(i) / float(n) + anim
            ebul.append({"pos": origin, "vel": Vector2(cos(a), sin(a)) * 160.0})
    elif k == "radial":
        for i in range(8):
            var a: float = TAU * float(i) / 8.0
            ebul.append({"pos": origin, "vel": Vector2(cos(a), sin(a)) * 150.0})
    elif k == "aimed":
        var d := (ppos - origin).normalized()
        ebul.append({"pos": origin, "vel": d * 220.0})
    else:
        var a: float = float(e["t"]) * 3.0
        ebul.append({"pos": origin, "vel": Vector2(cos(a), sin(a)) * 170.0})

func _collisions() -> void:
    var pk: Array = []
    for b in pbul:
        var hit := false
        for e in enemies:
            var rad := 30.0 if e["boss"] else 16.0
            if b["pos"].distance_to(e["pos"]) < rad:
                e["hp"] = int(e["hp"]) - int(b["dmg"])
                hit = true
                if not bool(b.get("pierce", false)):
                    break
        if not hit or bool(b.get("pierce", false)):
            pk.append(b)
    pbul = pk
    var alive: Array = []
    for e in enemies:
        if int(e["hp"]) > 0:
            alive.append(e)
    enemies = alive
    var iframe := roll_t > (ROLL_TIME - ROLL_IFRAME)
    if not iframe:
        var keep: Array = []
        for b in ebul:
            if b["pos"].distance_to(ppos) < PR + 5.0:
                hp -= 1
            else:
                keep.append(b)
        ebul = keep

func _on_room_clear() -> void:
    rooms_cleared += 1
    if room >= 3:
        _finish(true)
        return
    gun = (gun + 1) % GUNS.size()
    room += 1
    msg = "Room cleared! Picked up %s. Entering room %d." % [GUNS[gun]["name"], room]
    if room >= 3:
        _spawn_boss()
    else:
        _spawn_room(room)

func _finish(victory: bool) -> void:
    won = victory
    mode = "result"
    queue_redraw()

func _fire() -> void:
    if mode != "play" or fire_cd > 0.0:
        return
    var g: Dictionary = GUNS[gun]
    fire_cd = float(g["cd"])
    var d := (aim - ppos).normalized()
    var pat: String = str(g["pat"])
    var spd: float = float(g["spd"])
    var dmg: int = int(g["dmg"])
    if pat == "spread":
        for off in [-0.25, -0.12, 0.0, 0.12, 0.25]:
            pbul.append({"pos": ppos, "vel": d.rotated(off) * spd, "dmg": dmg, "pierce": false})
    elif pat == "pierce":
        pbul.append({"pos": ppos, "vel": d * spd, "dmg": dmg, "pierce": true})
    else:
        pbul.append({"pos": ppos, "vel": d * spd, "dmg": dmg, "pierce": false})

func _roll() -> void:
    if mode == "play" and roll_t == 0.0:
        roll_t = ROLL_TIME

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.07, 0.06, 0.09))
    match mode:
        "title": _draw_title()
        "play": _draw_play()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.05, 0.04, 0.07, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.5, 0.45, 0.6, 0.9), false, 2.0)

func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.14, 0.12, 0.18)); draw_rect(r, Color(0.6, 0.5, 0.7), false, 2.0)
    _text(label, r.position + Vector2(16, r.size.y * 0.64), 20, Color(0.9, 0.88, 0.95))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("BULLET CATHEDRAL", Vector2(380, 250), 50, Color(0.75, 0.62, 0.9))
    _text("Descend the cathedral. Roll through the bullets. Fire back.", Vector2(360, 312), 18, Color(0.82, 0.8, 0.9))
    _button(Rect2(500, 410, 280, 64), "BEGIN RUN")

func _draw_play() -> void:
    draw_rect(ARENA, Color(0.11, 0.10, 0.14))
    draw_rect(ARENA, Color(0.4, 0.35, 0.5), false, 3.0)
    for e in enemies:
        var col := Color(0.9, 0.4, 0.4)
        if e["boss"]: col = Color(0.95, 0.3, 0.6)
        elif e["kind"] == "aimed": col = Color(0.9, 0.7, 0.3)
        elif e["kind"] == "spiral": col = Color(0.6, 0.8, 0.4)
        var rad := 26.0 if e["boss"] else 15.0
        draw_circle(e["pos"], rad, col)
        if e["boss"]:
            _bar(Rect2(e["pos"].x - 60, e["pos"].y - 44, 120, 8), float(e["hp"]) / 30.0, Color(0.95, 0.3, 0.6))
    for b in ebul:
        draw_circle(b["pos"], 5.0, Color(0.95, 0.55, 0.25))
    for b in pbul:
        draw_circle(b["pos"], 4.0, Color(0.6, 0.9, 1.0))
    if roll_t > 0.0:
        draw_arc(ppos, PR + 8, 0, TAU, 20, Color(0.7, 0.95, 1.0, 0.7), 3.0)
    draw_circle(ppos, PR, Color(0.45, 0.8, 0.95))
    draw_line(ppos, ppos + (aim - ppos).normalized() * 26.0, Color(1, 1, 1, 0.6), 2.0)
    _panel(Rect2(0, 0, 1280, 64))
    for i in range(MAX_HP):
        var on := i < hp
        draw_circle(Vector2(30 + i * 28, 32), 10, Color(0.9, 0.3, 0.35) if on else Color(0.25, 0.2, 0.22))
    _text("Room %d/3" % room, Vector2(360, 40), 22, Color(0.85, 0.82, 0.92))
    _text("Gun: %s" % str(GUNS[gun]["name"]), Vector2(540, 40), 20, Color(0.7, 0.85, 0.95))
    _text("Cleared: %d" % rooms_cleared, Vector2(760, 40), 20, Color(0.8, 0.8, 0.7))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.82, 0.9))

func _bar(r: Rect2, frac: float, c: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(r, Color(0.1, 0.08, 0.1))
    draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), c)

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    if won:
        _text("CATHEDRAL CLEARED", Vector2(360, 270), 44, Color(0.6, 0.95, 0.6))
    else:
        _text("YOU FELL", Vector2(480, 270), 44, Color(0.95, 0.4, 0.4))
    _text("Rooms cleared: %d" % rooms_cleared, Vector2(420, 330), 22, Color(0.85, 0.85, 0.9))
    _text("Reached room %d of 3" % room, Vector2(420, 366), 20, Color(0.8, 0.8, 0.85))
    _button(Rect2(420, 420, 180, 54), "RETRY")
    _button(Rect2(660, 420, 180, 54), "TITLE")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_SPACE:
                if p and not event.echo: _roll()
    if event is InputEventMouseMotion:
        aim = event.position
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        aim = event.position
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position):
                _start_run(); _spawn_room(1); queue_redraw()
        elif mode == "play":
            _fire()
        elif mode == "result":
            if Rect2(420, 420, 180, 54).has_point(event.position):
                _start_run(); _spawn_room(1); queue_redraw()
            elif Rect2(660, 420, 180, 54).has_point(event.position):
                mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_combat.json" <<'EOF'
{
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 70,  "type": "key_down", "keycode": "D"},
    {"frame": 110, "type": "mouse_move", "x": 800, "y": 300},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 800, "y": 300},
    {"frame": 160, "type": "key_up", "keycode": "D"},
    {"frame": 180, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "mouse_click", "button": "left", "x": 700, "y": 360},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 600, "y": 300},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_combat_fire.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 760, "y": 280},
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 760, "y": 280},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 130, "type": "mouse_click", "button": "left", "x": 820, "y": 480},
    {"frame": 200, "type": "key_down", "keycode": "A"},
    {"frame": 240, "type": "key_up", "keycode": "A"},
    {"frame": 280, "type": "mouse_click", "button": "left", "x": 700, "y": 360},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_dodge_roll.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 400,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_down", "keycode": "W"},
    {"frame": 200, "type": "key_up", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_boss.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 640, "y": 220},
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 640, "y": 220},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "mouse_click", "button": "left", "x": 640, "y": 220},
    {"frame": 200, "type": "key_down", "keycode": "D"},
    {"frame": 240, "type": "key_up", "keycode": "D"},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 640, "y": 220},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_death.json" <<'EOF'
{
  "scenario": "death",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 200, "type": "wait"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

echo "bullet-cathedral oracle generated at $GAME"
