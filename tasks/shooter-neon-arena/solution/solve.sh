#!/bin/bash
# Reference solution for gamecraft-bench/shooter-neon-arena.
#
# A compact twin-stick arena survival shooter:
#   - Title -> arena. WASD move (free 360), mouse aim + click fire, E bomb.
#   - Waves of enemies spawn from edges (rushing / circling / splitting types),
#     escalating per wave; clear a wave to trigger an upgrade prompt.
#   - Score multiplier rises with consecutive kills in a window; taking a hit
#     resets it to 1x. Limited lives; 0 lives = game over.
#   - Bomb clears all enemies/projectiles on screen (limited charges).
#   - Boss wave every few waves. Game-over screen shows score/chain stats.
#   - Scenarios jump to combat / upgrade / boss / death for deterministic demos.
#
# Oracle for the verifier: primitives only, art items (A*) stay low while
# mechanic/content items pass. Logic in _physics_process for determinism.
#
# NOTE (GDScript warnings-as-errors): explicit types on Dictionary-subscript /
# min()/max() derived values to avoid inferred-Variant parse errors.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="NeonArena"
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
const ARENA := Rect2(140, 100, 1000, 520)
const PR := 13.0
const MAX_LIVES := 3

const UPGRADES := ["Spread Shot", "Fire Rate+", "Damage+", "Extra Bomb"]

var scenario := ""
var mode := "title"          # title, play, upgrade, result
var wave := 1
var score := 0
var mult := 1
var mult_t := 0.0
var best_chain := 1
var lives := MAX_LIVES
var bombs := 2
var spread := false
var firerate := 0.22
var dmg := 1
var ppos := Vector2(640, 360)
var aim := Vector2(800, 360)
var move := {"up": false, "down": false, "left": false, "right": false}
var fire_cd := 0.0
var bullets: Array = []
var enemies: Array = []
var hurt_t := 0.0
var bombflash := 0.0
var anim := 0.0
var msg := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 5150
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
        _start(); _spawn_wave(1)
    elif id == "upgrade":
        _start(); mode = "upgrade"
    elif id == "boss":
        _start(); wave = 5; _spawn_boss()
    elif id == "near_victory":
        _start(); _spawn_wave(1)
        while enemies.size() > 1:
            enemies.pop_back()
    elif id == "death":
        _start(); lives = 1; _spawn_wave(1)
    else:
        _start(); _spawn_wave(1)

func _start() -> void:
    mode = "play"
    wave = 1
    score = 0
    mult = 1
    mult_t = 0.0
    lives = MAX_LIVES
    bombs = 2
    spread = false
    firerate = 0.22
    dmg = 1
    ppos = Vector2(640, 360)
    bullets = []
    enemies = []
    msg = "Survive. WASD move, click fire, E bomb. Keep the chain alive!"

func _spawn_wave(n: int) -> void:
    enemies = []
    var count := 4 + n * 2
    var kinds := ["rush", "circle", "split"]
    for i in range(count):
        var edge := i % 4
        var pos := Vector2(640, 360)
        if edge == 0: pos = Vector2(ARENA.position.x + 20, ARENA.position.y + 40 + float(i) * 30)
        elif edge == 1: pos = Vector2(ARENA.end.x - 20, ARENA.position.y + 40 + float(i) * 30)
        elif edge == 2: pos = Vector2(ARENA.position.x + 60 + float(i) * 40, ARENA.position.y + 20)
        else: pos = Vector2(ARENA.position.x + 60 + float(i) * 40, ARENA.end.y - 20)
        enemies.append({"pos": pos, "hp": 2, "kind": kinds[i % 3], "t": float(i), "boss": false})

func _spawn_boss() -> void:
    enemies = [{"pos": Vector2(640, 200), "hp": 30, "kind": "boss", "t": 0.0, "boss": true}]
    msg = "BOSS WAVE"

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "play":
        return
    fire_cd = max(0.0, fire_cd - delta)
    hurt_t = max(0.0, hurt_t - delta)
    bombflash = max(0.0, bombflash - delta)
    mult_t = max(0.0, mult_t - delta)
    if mult_t <= 0.0 and mult > 1:
        mult = 1

    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    ppos += dir.normalized() * 260.0 * delta
    ppos.x = clampf(ppos.x, ARENA.position.x + PR, ARENA.end.x - PR)
    ppos.y = clampf(ppos.y, ARENA.position.y + PR, ARENA.end.y - PR)

    var bk: Array = []
    for b in bullets:
        b["pos"] += b["vel"] * delta
        if ARENA.grow(20).has_point(b["pos"]):
            bk.append(b)
    bullets = bk

    for e in enemies:
        e["t"] += delta
        var k: String = str(e["kind"])
        var to: Vector2 = (ppos - e["pos"]).normalized()
        if k == "circle":
            var perp := Vector2(-to.y, to.x)
            e["pos"] += (to * 30.0 + perp * 70.0) * delta
        else:
            var spd := 110.0 if k == "rush" else 70.0
            e["pos"] += to * spd * delta
        if e["pos"].distance_to(ppos) < PR + 14.0 and hurt_t <= 0.0:
            _take_hit()

    _collisions()
    if enemies.size() == 0:
        _wave_clear()
    queue_redraw()

func _take_hit() -> void:
    lives -= 1
    hurt_t = 1.2
    mult = 1   # chain reset on hit
    if lives <= 0:
        _finish()

func _collisions() -> void:
    var keep: Array = []
    for b in bullets:
        var hit := false
        for e in enemies:
            var rad := 28.0 if e["boss"] else 14.0
            if b["pos"].distance_to(e["pos"]) < rad:
                e["hp"] = int(e["hp"]) - int(b["dmg"])
                hit = true
                break
        if not hit:
            keep.append(b)
    bullets = keep
    var alive: Array = []
    for e in enemies:
        if int(e["hp"]) > 0:
            alive.append(e)
        else:
            _on_kill(e)
    enemies = alive

func _on_kill(e: Dictionary) -> void:
    mult = min(mult + 1, 9)
    mult_t = 1.6
    if mult > best_chain:
        best_chain = mult
    score += 50 * mult
    # split enemy spawns two weaker on death
    if str(e["kind"]) == "split" and not e["boss"]:
        for s in [-1, 1]:
            enemies.append({"pos": e["pos"] + Vector2(s * 20, 0), "hp": 1, "kind": "rush", "t": 0.0, "boss": false})

func _wave_clear() -> void:
    if wave >= 5:
        _finish(true)
        return
    mode = "upgrade"
    msg = "Wave %d cleared! Choose an upgrade." % wave

func _apply_upgrade(i: int) -> void:
    match i:
        0: spread = true
        1: firerate = max(0.08, firerate - 0.06)
        2: dmg += 1
        3: bombs += 1
    wave += 1
    mode = "play"
    if wave >= 5:
        _spawn_boss()
    else:
        _spawn_wave(wave)

func _fire() -> void:
    if mode != "play" or fire_cd > 0.0:
        return
    fire_cd = firerate
    var d := (aim - ppos).normalized()
    if spread:
        for off in [-0.15, 0.0, 0.15]:
            bullets.append({"pos": ppos, "vel": d.rotated(off) * 700.0, "dmg": dmg})
    else:
        bullets.append({"pos": ppos, "vel": d * 760.0, "dmg": dmg})

func _bomb() -> void:
    if mode != "play" or bombs <= 0:
        return
    bombs -= 1
    bombflash = 0.5
    for e in enemies:
        if not e["boss"]:
            e["hp"] = 0
        else:
            e["hp"] = int(e["hp"]) - 8
    _collisions()
    if enemies.size() == 0:
        _wave_clear()

func _finish(victory := false) -> void:
    mode = "result"
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.04, 0.04, 0.08))
    match mode:
        "title": _draw_title()
        "play": _draw_play()
        "upgrade": _draw_upgrade()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.05, 0.05, 0.12, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.3, 0.9, 0.95, 0.9), false, 2.0)

func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.08, 0.10, 0.20)); draw_rect(r, Color(0.4, 0.95, 0.9), false, 2.0)
    _text(label, r.position + Vector2(16, r.size.y * 0.64), 20, Color(0.7, 1.0, 0.95))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("NEON ARENA", Vector2(440, 250), 54, Color(0.4, 0.95, 0.95))
    _text("Last pilot standing. Chain kills, keep the multiplier alive.", Vector2(375, 312), 18, Color(0.7, 0.95, 0.95))
    _button(Rect2(500, 410, 280, 64), "ENTER ARENA")

func _draw_play() -> void:
    draw_rect(ARENA, Color(0.06, 0.07, 0.14))
    draw_rect(ARENA, Color(0.3, 0.9, 0.95), false, 3.0)
    for e in enemies:
        var col := Color(0.95, 0.3, 0.6)
        var k: String = str(e["kind"])
        if e["boss"]: col = Color(1.0, 0.4, 0.9)
        elif k == "circle": col = Color(0.4, 0.9, 0.6)
        elif k == "split": col = Color(0.95, 0.8, 0.3)
        var rad := 26.0 if e["boss"] else 12.0
        var pts := PackedVector2Array()
        var n := 6 if k == "circle" else 3
        for i in range(n):
            var a := TAU * float(i) / float(n) + float(e["t"])
            pts.append(e["pos"] + Vector2(cos(a), sin(a)) * rad)
        draw_colored_polygon(pts, col)
        if e["boss"]:
            _bar(Rect2(e["pos"].x - 50, e["pos"].y - 40, 100, 8), float(e["hp"]) / 30.0, Color(1, 0.4, 0.9))
    for b in bullets:
        draw_circle(b["pos"], 4.0, Color(0.6, 1.0, 1.0))
    var pc := Color(0.5, 1.0, 1.0)
    if hurt_t > 0.0 and int(anim * 12) % 2 == 0: pc = Color(1, 0.4, 0.4)
    draw_circle(ppos, PR, pc)
    draw_line(ppos, ppos + (aim - ppos).normalized() * 26.0, Color(1, 1, 1, 0.6), 2.0)
    if bombflash > 0.0:
        draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.6, 1.0, 1.0, bombflash))
    _panel(Rect2(0, 0, 1280, 56))
    _text("Wave %d/5" % wave, Vector2(24, 38), 22, Color(0.7, 0.95, 0.95))
    _text("Score %d" % score, Vector2(200, 38), 22, Color(0.95, 0.95, 0.5))
    _text("x%d" % mult, Vector2(420, 38), 26, Color(1.0, 0.5, 0.7) if mult > 1 else Color(0.6, 0.7, 0.7))
    for i in range(MAX_LIVES):
        draw_circle(Vector2(560 + i * 26, 30), 9, Color(0.9, 0.3, 0.4) if i < lives else Color(0.2, 0.2, 0.25))
    _text("Bombs %d" % bombs, Vector2(720, 38), 20, Color(0.6, 0.95, 1.0))
    _text(msg, Vector2(40, 700), 16, Color(0.7, 0.9, 0.9))

func _bar(r: Rect2, frac: float, c: Color) -> void:
    frac = clampf(frac, 0.0, 1.0)
    draw_rect(r, Color(0.1, 0.1, 0.15))
    draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), c)

func _draw_upgrade() -> void:
    _draw_play()
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.55))
    _panel(Rect2(340, 200, 600, 320))
    _text("WAVE %d CLEARED" % wave, Vector2(420, 260), 34, Color(0.4, 0.95, 0.95))
    _text("Choose an upgrade:", Vector2(420, 300), 20, Color(0.8, 0.95, 0.95))
    for i in range(UPGRADES.size()):
        _button(Rect2(400 + (i % 2) * 240, 330 + (i / 2) * 80, 220, 60), UPGRADES[i])

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    _text("GAME OVER", Vector2(470, 260), 46, Color(1.0, 0.5, 0.7))
    _text("Final score: %d" % score, Vector2(420, 320), 24, Color(0.95, 0.95, 0.5))
    _text("Highest chain: x%d   Reached wave %d" % [best_chain, wave], Vector2(420, 360), 20, Color(0.7, 0.95, 0.95))
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
            KEY_E:
                if p and not event.echo: _bomb()
    if event is InputEventMouseMotion:
        aim = event.position
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        aim = event.position
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position):
                _start(); _spawn_wave(1); queue_redraw()
        elif mode == "play":
            _fire()
        elif mode == "upgrade":
            for i in range(UPGRADES.size()):
                if Rect2(400 + (i % 2) * 240, 330 + (i / 2) * 80, 220, 60).has_point(event.position):
                    _apply_upgrade(i); return
        elif mode == "result":
            if Rect2(420, 420, 180, 54).has_point(event.position):
                _start(); _spawn_wave(1); queue_redraw()
            elif Rect2(660, 420, 180, 54).has_point(event.position):
                mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_combat.json" <<'EOF'
{
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 70,  "type": "mouse_move", "x": 300, "y": 200},
    {"frame": 80,  "type": "mouse_click", "button": "left", "x": 300, "y": 200},
    {"frame": 140, "type": "mouse_move", "x": 980, "y": 200},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 980, "y": 200},
    {"frame": 220, "type": "mouse_click", "button": "left", "x": 640, "y": 140},
    {"frame": 300, "type": "key_press", "keycode": "E"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_chain.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 200, "y": 180},
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 200, "y": 180},
    {"frame": 90,  "type": "mouse_move", "x": 1080, "y": 180},
    {"frame": 100, "type": "mouse_click", "button": "left", "x": 1080, "y": 180},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 640, "y": 120},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 640, "y": 600},
    {"frame": 280, "type": "key_press", "keycode": "E"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_upgrade.json" <<'EOF'
{
  "scenario": "upgrade",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 510, "y": 360},
    {"frame": 140, "type": "mouse_move", "x": 700, "y": 250},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 700, "y": 250},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_boss.json" <<'EOF'
{
  "scenario": "boss",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_move", "x": 640, "y": 200},
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 640, "y": 200},
    {"frame": 100, "type": "key_press", "keycode": "E"},
    {"frame": 160, "type": "mouse_click", "button": "left", "x": 640, "y": 200},
    {"frame": 240, "type": "key_down", "keycode": "A"},
    {"frame": 280, "type": "key_up", "keycode": "A"},
    {"frame": 320, "type": "mouse_click", "button": "left", "x": 640, "y": 200},
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
    {"frame": 300, "type": "wait"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

echo "neon-arena oracle generated at $GAME"
