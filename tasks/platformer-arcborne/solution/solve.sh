#!/bin/bash
# Reference solution for gamecraft-bench/platformer-arcborne.
#
# Generates a compact grappling-hook swing momentum platformer:
#   - Title -> play one continuous course -> result (clear/medal), retry/next.
#   - Grapple: SPACE attaches to the nearest anchor, hold to swing (pendulum
#     physics under gravity), release to launch with preserved momentum; chain.
#   - Movement tech: A/D pump+steer, W/S reel the line in/out, E air-dash.
#   - Three themed zones (jungle -> city -> sci-fi) with their own backdrop and
#     a distinct environment modifier: jungle gust, city conveyor, sci-fi low
#     gravity.
#   - Anchor variety (fixed / moving / single-use breakable), hazard variety
#     (spike, moving saw, beam, moving platform) plus pits. Checkpoints; falling
#     or touching a hazard respawns at the last checkpoint.
#   - Time-attack: running clock, gold/silver/bronze medal at the goal.
#   - Deterministic: fixed-step _physics_process, no wall-clock game logic.
#   - Demos cover the loop, swinging, the sci-fi low-grav world, a goal clear,
#     and a fall/respawn.
#
# The whole game lives in one Main.gd. It is the oracle for the verifier
# framework, not a polished game: everything is drawn from primitives, so the
# art items (A1-A5) stay low while the mechanic and depth items pass.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Arcborne"
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
const GROUND_Y := 560.0
const PR := 14.0            # player radius
const GAPX := 480.0
const N := 10               # platforms
const GRAPPLE_RANGE := 380.0
const ROPE_MIN := 60.0
const ROPE_MAX := 260.0
const KILL_Y := 820.0

var scenario := ""
var mode := "title"

# World geometry (world coordinates)
var platforms: Array = []   # Rect2
var movers: Array = []      # {rect, base_y, t}
var anchors: Array = []     # {base, kind, t, broken, cur}
var spikes: Array = []      # Rect2 (spikes / beams)
var saws: Array = []        # {c, r, t, cx}
var checkpoints: Array = [] # floats (x)
var goal_x := 0.0

# Player
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var grounded := false
var attached := false
var attached_idx := -1
var rope_len := 200.0
var dash_ready := true
var hook_mode := "swing"   # "swing" (pendulum) or "pull" (retract to anchor)

# Run
var run_time := 0.0
var deaths := 0
var result_win := false
var medal := ""
var cam_x := 0.0

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
    if id == "run_start":
        _start_run()
    elif id == "scifi":
        _start_run()
        pos = Vector2(platforms[7]["position"].x + 30.0, GROUND_Y - 60.0)
        vel = Vector2.ZERO
        cam_x = pos.x - 440.0
    elif id == "near_goal":
        _start_run()
        pos = Vector2(goal_x - 300.0, GROUND_Y - 60.0)
        vel = Vector2(120.0, 0.0)
        cam_x = pos.x - 440.0
    elif id == "near_fall":
        _start_run()
        # Stranded airborne over a pit, drifting forward into it.
        pos = Vector2(platforms[1]["position"].x + 320.0, GROUND_Y - 120.0)
        vel = Vector2(40.0, 40.0)
        attached = false
        cam_x = pos.x - 440.0
    else:
        mode = "title"

func _zone_of(x: float) -> String:
    if platforms.size() < 8:
        return "jungle"
    if x < platforms[4]["position"].x:
        return "jungle"
    elif x < platforms[7]["position"].x:
        return "city"
    return "scifi"

func _grav_at(x: float) -> float:
    return 430.0 if _zone_of(x) == "scifi" else 950.0

func _build_course() -> void:
    platforms = []
    movers = []
    anchors = []
    spikes = []
    saws = []
    checkpoints = []
    for i in range(N):
        var px := 120.0 + float(i) * GAPX
        platforms.append(Rect2(px, GROUND_Y, 220, 40))
        if i < N - 1:
            var kind: String = ["fixed", "move", "break"][i % 3]
            anchors.append({
                "base": Vector2(px + GAPX * 0.62, 300.0),
                "kind": kind, "t": 0.0, "broken": false,
                "cur": Vector2(px + GAPX * 0.62, 300.0),
            })
    checkpoints = [platforms[0]["position"].x + 20.0, platforms[4]["position"].x + 20.0, platforms[7]["position"].x + 20.0]
    # Hazards: a spike strip, a moving saw, a sci-fi beam, plus a moving platform.
    spikes.append(Rect2(platforms[3]["position"].x + 60.0, GROUND_Y - 18.0, 90, 18))
    spikes.append(Rect2(platforms[8]["position"].x + 150.0, GROUND_Y - 170.0, 16, 170))
    saws.append({"cx": platforms[6]["position"].x + 110.0, "c": Vector2(platforms[6]["position"].x + 110.0, GROUND_Y - 60.0), "r": 26.0, "t": 0.0})
    movers.append({"rect": Rect2(platforms[7]["position"].x + GAPX * 0.5, GROUND_Y - 40.0, 150, 30), "base_y": GROUND_Y - 40.0, "t": 0.0})
    goal_x = platforms[N - 1]["position"].x + 130.0

func _start_run() -> void:
    _build_course()
    pos = Vector2(platforms[0]["position"].x + 40.0, GROUND_Y - 60.0)
    vel = Vector2.ZERO
    grounded = true
    attached = false
    attached_idx = -1
    dash_ready = true
    run_time = 0.0
    deaths = 0
    cam_x = 0.0
    mode = "play"

# --------------------------------------------------------------------------
# Simulation (fixed step)
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    if mode != "play":
        return
    run_time += delta
    # Update moving anchors / saw / moving platform.
    for a in anchors:
        a["t"] += delta
        if a["kind"] == "move" and not a["broken"]:
            a["cur"] = a["base"] + Vector2(sin(a["t"] * 1.5) * 90.0, 0.0)
        else:
            a["cur"] = a["base"]
    for s in saws:
        s["t"] += delta
        s["c"] = Vector2(s["cx"] + sin(s["t"] * 1.2) * 70.0, GROUND_Y - 60.0)
    for m in movers:
        m["t"] += delta
        m["rect"].position.y = m["base_y"] + sin(m["t"] * 1.4) * 70.0

    var grav := _grav_at(pos.x)
    var zone := _zone_of(pos.x)

    if attached and attached_idx >= 0:
        var ap: Vector2 = anchors[attached_idx]["cur"]
        if hook_mode == "pull":
            # Pull/retract hook: yank straight to the anchor, keep momentum on arrival.
            var to := ap - pos
            if to.length() <= 42.0:
                attached = false
                attached_idx = -1
            else:
                vel = to.normalized() * 520.0
                pos += vel * delta
        else:
            # Swing hook: pendulum under gravity.
            vel.y += grav * delta
            if zone == "jungle":
                vel.x += 70.0 * delta  # gust shoves along the swing
            pos += vel * delta
            var d := pos - ap
            if d.length() > rope_len:
                var n := d.normalized()
                pos = ap + n * rope_len
                var radial := vel.dot(n)
                if radial > 0.0:
                    vel -= n * radial
    else:
        vel.y += grav * delta
        if grounded:
            vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
            if zone == "city":
                vel.x += 90.0 * delta  # conveyor drag
        pos += vel * delta
        _resolve_ground()

    _check_hazards()
    if pos.y > KILL_Y:
        _die()
    elif pos.x >= goal_x:
        _finish()
    cam_x = clampf(pos.x - 440.0, 0.0, goal_x + 200.0)
    queue_redraw()

func _solids() -> Array:
    var out: Array = []
    for p in platforms:
        out.append(p)
    for m in movers:
        out.append(m["rect"])
    return out

func _resolve_ground() -> void:
    grounded = false
    var feet := pos.y + PR
    for r in _solids():
        if pos.x > r.position.x - 6.0 and pos.x < r.position.x + r.size.x + 6.0:
            if vel.y >= 0.0 and feet >= r.position.y and feet <= r.position.y + 26.0:
                pos.y = r.position.y - PR
                vel.y = 0.0
                grounded = true
                dash_ready = true
                break

func _check_hazards() -> void:
    for sp in spikes:
        if Rect2(sp.position - Vector2(PR, PR), sp.size + Vector2(PR * 2, PR * 2)).has_point(pos):
            _die()
            return
    for s in saws:
        if pos.distance_to(s["c"]) <= s["r"] + PR:
            _die()
            return

func _die() -> void:
    deaths += 1
    var cp: float = checkpoints[0]
    for c in checkpoints:
        if c <= pos.x:
            cp = c
    pos = Vector2(cp, GROUND_Y - 60.0)
    vel = Vector2.ZERO
    attached = false
    attached_idx = -1
    dash_ready = true

func _finish() -> void:
    result_win = true
    if run_time <= 14.0:
        medal = "GOLD"
    elif run_time <= 22.0:
        medal = "SILVER"
    else:
        medal = "BRONZE"
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

func _attach() -> void:
    if mode != "play":
        return
    var best := -1
    var bd := GRAPPLE_RANGE
    for i in range(anchors.size()):
        if anchors[i]["broken"]:
            continue
        var d := pos.distance_to(anchors[i]["cur"])
        if d < bd:
            bd = d
            best = i
    if best >= 0:
        attached = true
        attached_idx = best
        rope_len = clampf(bd, ROPE_MIN, ROPE_MAX)
        grounded = false

func _release() -> void:
    if attached and attached_idx >= 0:
        if anchors[attached_idx]["kind"] == "break":
            anchors[attached_idx]["broken"] = true
    attached = false
    attached_idx = -1

func _steer(dir: float) -> void:
    vel.x += dir * 150.0

func _reel(amount: float) -> void:
    if attached:
        rope_len = clampf(rope_len + amount, ROPE_MIN, ROPE_MAX)

func _dash() -> void:
    if mode != "play" or grounded or not dash_ready:
        return
    vel += Vector2(1.0, -0.3).normalized() * 460.0
    dash_ready = false

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _zone_bg(zone: String) -> Color:
    match zone:
        "jungle": return Color(0.10, 0.20, 0.12)
        "city": return Color(0.12, 0.13, 0.18)
        "scifi": return Color(0.08, 0.10, 0.18)
    return Color(0.1, 0.1, 0.12)

func _w2s(p: Vector2) -> Vector2:
    return Vector2(p.x - cam_x, p.y)

func _draw() -> void:
    if mode == "title":
        _draw_title()
        return
    var zone := _zone_of(pos.x)
    draw_rect(Rect2(Vector2.ZERO, VIEW), _zone_bg(zone))
    # parallax-ish backdrop strokes
    for i in range(20):
        var bx := fmod(float(i) * 140.0 - cam_x * 0.4, 1340.0) - 60.0
        draw_rect(Rect2(bx, 120, 60, 360), _zone_bg(zone).lerp(Color(1, 1, 1), 0.05))
    # solids
    for r in _solids():
        var sr := Rect2(_w2s(r.position), r.size)
        draw_rect(sr, Color(0.30, 0.34, 0.26))
        draw_rect(Rect2(sr.position, Vector2(sr.size.x, 8)), Color(0.46, 0.54, 0.36))
    # spikes / beams
    for sp in spikes:
        draw_rect(Rect2(_w2s(sp.position), sp.size), Color(0.85, 0.30, 0.30))
    # saws
    for s in saws:
        var c := _w2s(s["c"])
        draw_circle(c, s["r"], Color(0.80, 0.80, 0.85))
        draw_arc(c, s["r"], 0, TAU, 16, Color(0.5, 0.5, 0.55), 3.0)
    # anchors
    for a in anchors:
        if a["broken"]:
            continue
        var ac := _w2s(a["cur"])
        var col := Color(0.7, 0.7, 0.4)
        if a["kind"] == "move":
            col = Color(0.4, 0.7, 0.9)
        elif a["kind"] == "break":
            col = Color(0.9, 0.6, 0.4)
        draw_circle(ac, 10, col)
        draw_arc(ac, 14, 0, TAU, 16, col, 2.0)
    # goal flag
    var gp := _w2s(Vector2(goal_x, GROUND_Y))
    draw_rect(Rect2(gp + Vector2(-3, -120), Vector2(6, 120)), Color(0.9, 0.9, 0.9))
    draw_rect(Rect2(gp + Vector2(3, -120), Vector2(40, 26)), Color(0.95, 0.78, 0.30))
    # rope
    if attached and attached_idx >= 0:
        draw_line(_w2s(pos), _w2s(anchors[attached_idx]["cur"]), Color(0.92, 0.86, 0.6), 3.0)
    # player
    var pp := _w2s(pos)
    draw_circle(pp, PR, Color(0.45, 0.78, 0.95))
    draw_circle(pp + Vector2(0, -PR - 4), 7, Color(0.85, 0.9, 1.0))
    _draw_hud(zone)
    if mode == "result":
        _draw_result()

func _panel(rect: Rect2, color := Color(0.06, 0.08, 0.10, 0.92)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.40, 0.50, 0.60, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color(0.12, 0.16, 0.18))
    draw_rect(rect, Color(0.5, 0.66, 0.7), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 20, Color(0.9, 0.95, 0.95))

func _draw_title() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.09, 0.13, 0.18))
    _panel(Rect2(330, 160, 620, 340))
    _text("ARCBORNE", Vector2(440, 250), 64, Color(0.6, 0.85, 0.95))
    _text("Hook, swing, release. Chain your momentum across three worlds.", Vector2(366, 312), 19, Color(0.78, 0.86, 0.9))
    _button(Rect2(520, 420, 240, 70), "START RUN")

func _draw_hud(zone: String) -> void:
    _panel(Rect2(16, 14, 1248, 56))
    _text("TIME %0.1f" % run_time, Vector2(36, 50), 24, Color(0.92, 0.94, 0.7))
    var names := {"jungle": "I. Jungle", "city": "II. City", "scifi": "III. Sci-Fi"}
    _text("World %s" % names.get(zone, zone), Vector2(220, 50), 22, Color(0.8, 0.9, 0.95))
    var prog := clampf((pos.x - platforms[0]["position"].x) / max(1.0, goal_x - platforms[0]["position"].x), 0.0, 1.0)
    _text("Progress %d%%" % int(prog * 100.0), Vector2(470, 50), 20, Color(0.85, 0.88, 0.8))
    _text("Deaths %d" % deaths, Vector2(660, 50), 20, Color(0.95, 0.7, 0.6))
    _text("Hook:%s" % hook_mode, Vector2(800, 50), 18, Color(0.7, 0.9, 0.95))
    _text("Gold<=14s Silver<=22s", Vector2(960, 50), 17, Color(0.9, 0.82, 0.45))

func _draw_result() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _panel(Rect2(360, 200, 560, 300))
    _text("COURSE CLEAR", Vector2(430, 270), 50, Color(0.7, 0.95, 0.7))
    _text("Time %0.1f s   Medal: %s" % [run_time, medal], Vector2(420, 330), 24, Color(0.92, 0.86, 0.5))
    _text("Deaths: %d" % deaths, Vector2(420, 366), 20, Color(0.9, 0.8, 0.75))
    _button(Rect2(420, 410, 180, 56), "RETRY")
    _button(Rect2(640, 410, 180, 56), "NEXT")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.pressed and not event.echo:
            match event.keycode:
                KEY_SPACE:
                    _attach()
                KEY_A, KEY_LEFT:
                    _steer(-1.0)
                KEY_D, KEY_RIGHT:
                    _steer(1.0)
                KEY_W, KEY_UP:
                    _reel(-40.0)
                KEY_S, KEY_DOWN:
                    _reel(40.0)
                KEY_1:
                    _dash()
                KEY_TAB:
                    hook_mode = "pull" if hook_mode == "swing" else "swing"
        elif not event.pressed:
            if event.keycode == KEY_SPACE:
                _release()
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _click_down(event.position)
            else:
                _release()
        return

func _click_down(p: Vector2) -> void:
    if mode == "title":
        if Rect2(520, 420, 240, 70).has_point(p):
            _start_run()
            queue_redraw()
    elif mode == "play":
        _attach()
    elif mode == "result":
        if Rect2(420, 410, 180, 56).has_point(p) or Rect2(640, 410, 180, 56).has_point(p):
            _start_run()
            queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_start.json" <<'EOF'
{
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 455},
    {"frame": 80,  "type": "key_down", "keycode": "SPACE"},
    {"frame": 120, "type": "key_press", "keycode": "D"},
    {"frame": 150, "type": "key_press", "keycode": "D"},
    {"frame": 190, "type": "key_up",   "keycode": "SPACE"},
    {"frame": 230, "type": "key_press", "keycode": "1"},
    {"frame": 350, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_swing.json" <<'EOF'
{
  "scenario": "run_start",
  "duration_frames": 400,
  "events": [
    {"frame": 25,  "type": "key_down", "keycode": "SPACE"},
    {"frame": 60,  "type": "key_press", "keycode": "D"},
    {"frame": 95,  "type": "key_press", "keycode": "W"},
    {"frame": 130, "type": "key_up",   "keycode": "SPACE"},
    {"frame": 175, "type": "key_down", "keycode": "SPACE"},
    {"frame": 215, "type": "key_press", "keycode": "D"},
    {"frame": 255, "type": "key_up",   "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_scifi.json" <<'EOF'
{
  "scenario": "scifi",
  "duration_frames": 400,
  "events": [
    {"frame": 20,  "type": "key_press", "keycode": "TAB"},
    {"frame": 40,  "type": "key_down", "keycode": "SPACE"},
    {"frame": 120, "type": "key_up",   "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "TAB"},
    {"frame": 190, "type": "key_down", "keycode": "SPACE"},
    {"frame": 240, "type": "key_press", "keycode": "D"},
    {"frame": 300, "type": "key_up",   "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_goal.json" <<'EOF'
{
  "scenario": "near_goal",
  "duration_frames": 360,
  "events": [
    {"frame": 25,  "type": "key_down", "keycode": "SPACE"},
    {"frame": 60,  "type": "key_press", "keycode": "D"},
    {"frame": 95,  "type": "key_up",   "keycode": "SPACE"},
    {"frame": 130, "type": "key_press", "keycode": "1"},
    {"frame": 280, "type": "mouse_click", "button": "left", "x": 510, "y": 438},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_fall.json" <<'EOF'
{
  "scenario": "near_fall",
  "duration_frames": 300,
  "events": [
    {"frame": 30,  "type": "wait"},
    {"frame": 200, "type": "wait"},
    {"frame": 290, "type": "wait"}
  ]
}
EOF

echo "arcborne oracle generated at $GAME"
